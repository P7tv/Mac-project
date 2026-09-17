import Foundation

public struct WebReceiver {
    public static let htmlContent: String = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>DeskExtend - Secondary Display</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
          width: 100vw;
          height: 100vh;
          overflow: hidden;
          background-color: #000;
          cursor: default;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        }
        #screen {
          width: 100vw;
          height: 100vh;
          object-fit: contain;
          display: block;
          image-rendering: -webkit-optimize-contrast;
        }
        #hud {
          position: fixed;
          top: 14px;
          right: 14px;
          background: rgba(15, 23, 42, 0.75);
          backdrop-filter: blur(10px);
          -webkit-backdrop-filter: blur(10px);
          border: 1px solid rgba(255, 255, 255, 0.15);
          color: #f8fafc;
          padding: 8px 14px;
          border-radius: 20px;
          font-size: 12px;
          font-weight: 500;
          display: flex;
          align-items: center;
          gap: 10px;
          z-index: 100;
          transition: opacity 0.4s ease;
          pointer-events: none;
          box-shadow: 0 4px 12px rgba(0,0,0,0.5);
        }
        .dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #22c55e;
          box-shadow: 0 0 8px #22c55e;
        }
        .dot.connecting {
          background: #f59e0b;
          box-shadow: 0 0 8px #f59e0b;
        }
        #overlay {
          position: fixed;
          top: 0; left: 0;
          width: 100vw; height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          background: rgba(10, 15, 30, 0.95);
          color: #fff;
          z-index: 50;
          transition: opacity 0.3s ease;
        }
        #overlay h1 { font-size: 28px; margin-bottom: 12px; font-weight: 700; }
        #overlay p { font-size: 14px; color: #94a3b8; margin-bottom: 24px; }
        .btn-fullscreen {
          padding: 10px 24px;
          background: #2563eb;
          color: #fff;
          border: none;
          border-radius: 8px;
          font-size: 14px;
          font-weight: 600;
          cursor: pointer;
          transition: background 0.2s;
        }
        .btn-fullscreen:hover { background: #1d4ed8; }
        .faded { opacity: 0; }
      </style>
    </head>
    <body>
      <div id="hud">
        <span class="dot" id="statusDot"></span>
        <span id="fpsCounter">-- FPS</span>
        <span style="color: #64748b;">|</span>
        <span id="resLabel">DeskExtend Display</span>
        <span style="color: #64748b;">|</span>
        <span style="color: #94a3b8;">F11 to Fullscreen</span>
      </div>

      <div id="overlay" onclick="enterFullscreen()">
        <h1>DeskExtend Display Connected</h1>
        <p>Click anywhere or press <strong>F11</strong> to go Fullscreen on this monitor</p>
        <button class="btn-fullscreen">Enter Fullscreen Monitor Mode</button>
      </div>

      <canvas id="screen"></canvas>

      <script>
        const canvas = document.getElementById('screen');
        const ctx = canvas.getContext('2d', { alpha: false });
        const hud = document.getElementById('hud');
        const statusDot = document.getElementById('statusDot');
        const fpsCounter = document.getElementById('fpsCounter');
        const overlay = document.getElementById('overlay');

        let frameCount = 0;
        let lastTime = performance.now();
        let isFirstFrame = true;
        let hudTimeout;

        function resetHudTimer() {
          hud.classList.remove('faded');
          clearTimeout(hudTimeout);
          hudTimeout = setTimeout(() => {
            hud.classList.add('faded');
          }, 4000);
        }
        window.addEventListener('mousemove', resetHudTimer);

        function enterFullscreen() {
          if (!document.fullscreenElement) {
            document.documentElement.requestFullscreen().catch(() => {});
          }
          overlay.style.opacity = '0';
          setTimeout(() => overlay.style.display = 'none', 300);
        }

        document.addEventListener('keydown', (e) => {
          if (e.key === 'f' || e.key === 'F') enterFullscreen();
        });

        function connect() {
          statusDot.className = 'dot connecting';
          const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
          const ws = new WebSocket(`${proto}//${location.host}/stream`);
          ws.binaryType = 'arraybuffer';

          ws.onopen = () => {
            statusDot.className = 'dot';
            resetHudTimer();
          };

          ws.onmessage = async (event) => {
            if (isFirstFrame) {
              isFirstFrame = false;
              overlay.style.opacity = '0';
              setTimeout(() => overlay.style.display = 'none', 300);
            }

            const blob = new Blob([event.data], { type: 'image/jpeg' });
            try {
              const imageBitmap = await createImageBitmap(blob);
              if (canvas.width !== imageBitmap.width || canvas.height !== imageBitmap.height) {
                canvas.width = imageBitmap.width;
                canvas.height = imageBitmap.height;
                document.getElementById('resLabel').innerText = `${imageBitmap.width}x${imageBitmap.height}`;
              }
              ctx.drawImage(imageBitmap, 0, 0);
              imageBitmap.close();

              frameCount++;
              const now = performance.now();
              if (now - lastTime >= 1000) {
                const fps = Math.round((frameCount * 1000) / (now - lastTime));
                fpsCounter.innerText = `${fps} FPS`;
                frameCount = 0;
                lastTime = now;
              }
            } catch (err) {
              // Frame decode error skip
            }
          };

          ws.onclose = () => {
            statusDot.className = 'dot connecting';
            fpsCounter.innerText = 'Reconnecting...';
            setTimeout(connect, 1500);
          };

          ws.onerror = () => ws.close();
        }

        connect();
      </script>
    </body>
    </html>
    """
}
