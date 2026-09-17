import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import test from 'node:test';

const swift = readFileSync(new URL('../Sources/DeskExtendCore/Resources/WebReceiver.swift', import.meta.url), 'utf8');
const script = swift.match(/<script>([\s\S]*?)<\/script>/)[1];
const flush = () => new Promise(resolve => setImmediate(resolve));

function receiver() {
  const drawn = [], closed = [], decodes = [], sockets = [];
  const elements = new Map();
  const getElement = id => {
    if (!elements.has(id)) elements.set(id, {
      style: {}, classList: { add() {}, remove() {} },
      getContext: () => ({ drawImage: bitmap => drawn.push(bitmap.id) }),
    });
    return elements.get(id);
  };
  class WebSocket {
    static OPEN = 1;
    readyState = 1;
    sent = [];
    constructor(url, protocol) { this.protocol = protocol; sockets.push(this); }
    send(bytes) { this.sent.push([...bytes]); }
    close() { this.readyState = 3; this.onclose(); }
  }
  runInNewContext(script, {
    document: { getElementById: getElement, addEventListener() {} },
    window: { addEventListener() {} },
    location: { protocol: 'http:', host: 'localhost:8080' },
    performance: { now: () => 0 },
    Blob, Uint8Array, WebSocket,
    setTimeout() {}, clearTimeout() {},
    createImageBitmap: blob => new Promise((resolve, reject) => {
      decodes.push({ blob, reject, finish: id => resolve({
        id, width: 1920, height: 1080, close: () => closed.push(id),
      }) });
    }),
  });
  return { ws: sockets[0], drawn, closed, decodes };
}

test('slow decoding is serial and queued obsolete frames are replaced', async () => {
  const r = receiver();
  r.ws.onmessage({ data: new Uint8Array([1]) });
  r.ws.onmessage({ data: new Uint8Array([2]) });
  r.ws.onmessage({ data: new Uint8Array([3]) });
  assert.equal(r.decodes.length, 1);
  r.decodes[0].finish(1);
  await flush();
  assert.equal(r.decodes.length, 2);
  assert.deepEqual([...new Uint8Array(await r.decodes[1].blob.arrayBuffer())], [3]);
  r.decodes[1].finish(3);
  await flush();
  assert.deepEqual(r.drawn, [1, 3]);
  assert.deepEqual(r.closed, [1, 3]);
  assert.deepEqual(r.ws.sent, [[1], [1]]);
});

test('failed decode acknowledges consumption so the stream can continue', async () => {
  const r = receiver();
  r.ws.onmessage({ data: new Uint8Array([1]) });
  r.decodes[0].reject(new Error('invalid JPEG'));
  await flush();
  assert.deepEqual(r.ws.sent, [[1]]);
  r.ws.onmessage({ data: new Uint8Array([2]) });
  r.decodes[1].finish(2);
  await flush();
  assert.deepEqual(r.drawn, [2]);
});

test('a frame decoded after disconnect is released without painting or acknowledging', async () => {
  const r = receiver();
  r.ws.onmessage({ data: new Uint8Array([1]) });
  r.ws.onmessage({ data: new Uint8Array([2]) });
  r.ws.close();
  r.decodes[0].finish(1);
  await flush();
  assert.deepEqual(r.drawn, []);
  assert.deepEqual(r.closed, [1]);
  assert.deepEqual(r.ws.sent, []);
  assert.equal(r.decodes.length, 1);
});
