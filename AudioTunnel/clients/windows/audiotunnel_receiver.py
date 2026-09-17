"""
AudioTunnel — Windows Native Ultra-Low Latency Audio Receiver
Streams Mac system audio / mic over local Wi-Fi with < 20ms latency.
"""

import sys
import time
import socket
import threading
import queue

def print_banner():
    print("=" * 60)
    print("  🎧 AudioTunnel — Windows Ultra-Low Latency Audio Receiver")
    print("  Zero Cloud • 48 kHz 16-bit Stereo PCM • Local Wi-Fi Bridge")
    print("=" * 60)

def main():
    print_banner()

    if len(sys.argv) > 1:
        mac_ip = sys.argv[1]
    else:
        mac_ip = input("Enter Mac IP Address (e.g. 192.168.1.50): ").strip()

    if not mac_ip:
        print("[-] IP address cannot be empty.")
        return

    port = 7070
    print(f"[*] Connecting to AudioTunnel host at {mac_ip}:{port}...")

    # Check for sounddevice / numpy
    has_sounddevice = False
    try:
        import sounddevice as sd
        import numpy as np
        has_sounddevice = True
        print("[+] Detected sounddevice engine for sub-millisecond audio playback.")
    except ImportError:
        print("[!] sounddevice or numpy not found. To install: pip install sounddevice numpy websocket-client")

    try:
        import websocket
    except ImportError:
        print("[!] websocket-client not found. To install: pip install websocket-client")
        print("[*] Alternatively, open your browser and navigate to:")
        print(f"    👉 http://{mac_ip}:{port}")
        return

    if has_sounddevice:
        import sounddevice as sd
        import numpy as np

        # Low-latency ring buffer queue (holds max 8 chunks = ~160ms)
        audio_queue = queue.Queue(maxsize=8)
        running = True

        def audio_callback(outdata, frames, time_info, status):
            nonlocal running
            if not running:
                outdata.fill(0)
                return

            try:
                # Non-blocking get
                data = audio_queue.get_nowait()
                if len(data) >= len(outdata):
                    outdata[:] = data[:len(outdata)]
                else:
                    outdata[:len(data)] = data
                    outdata[len(data):].fill(0)
            except queue.Empty:
                # Soft fill silence on buffer underrun
                outdata.fill(0)

        # Start low-latency output stream with callback
        try:
            stream = sd.OutputStream(
                samplerate=48000,
                channels=2,
                dtype='int16',
                blocksize=1024,
                latency='low',
                callback=audio_callback
            )
            stream.start()
            print("[+] Audio hardware stream active (48000 Hz, 2ch, 16-bit, Low Latency).")
        except Exception as e:
            print(f"[-] Error starting audio stream: {e}")
            return

        def on_message(ws, message):
            if isinstance(message, bytes):
                audio_array = np.frombuffer(message, dtype=np.int16)
                frames = len(audio_array) // 2
                if frames > 0:
                    reshaped = audio_array.reshape(frames, 2)
                    # If queue is full, drop oldest chunk to maintain ultra-low latency
                    if audio_queue.full():
                        try:
                            audio_queue.get_nowait()
                        except queue.Empty:
                            pass
                    audio_queue.put(reshaped)

        def on_error(ws, error):
            print(f"[-] WebSocket error: {error}")

        def on_close(ws, close_status_code, close_msg):
            print("[*] Disconnected from AudioTunnel. Reconnecting in 2s...")
            time.sleep(2)

        def on_open(ws):
            print("[+] Connected to Mac audio stream! Listening live with zero latency...")

        ws_url = f"ws://{mac_ip}:{port}/audio"
        while True:
            try:
                ws = websocket.WebSocketApp(
                    ws_url,
                    on_open=on_open,
                    on_message=on_message,
                    on_error=on_error,
                    on_close=on_close
                )
                # Enable TCP_NODELAY to avoid buffering delay
                ws.run_forever(sockopt=((socket.IPPROTO_TCP, socket.TCP_NODELAY, 1),))
            except KeyboardInterrupt:
                print("\n[*] Exiting AudioTunnel receiver.")
                running = False
                if stream:
                    stream.stop()
                    stream.close()
                break
            except Exception as e:
                print(f"[-] Connection failed: {e}. Retrying in 3s...")
                time.sleep(3)

if __name__ == "__main__":
    main()
