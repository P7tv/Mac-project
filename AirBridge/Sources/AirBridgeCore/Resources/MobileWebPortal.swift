import Foundation

public struct MobileWebPortal {
    public static let htmlContent: String = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>AirBridge — Universal Clipboard</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        body {
          background: #090d16;
          color: #f1f5f9;
          min-height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          padding: 20px 16px 40px;
        }
        .container {
          width: 100%;
          max-width: 480px;
          display: flex;
          flex-direction: column;
          gap: 16px;
        }
        .header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 8px 4px;
        }
        .brand {
          display: flex;
          align-items: center;
          gap: 10px;
        }
        .logo {
          width: 36px;
          height: 36px;
          border-radius: 10px;
          background: linear-gradient(135deg, #3b82f6, #06b6d4);
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 18px;
          box-shadow: 0 4px 14px rgba(59, 130, 246, 0.4);
        }
        .brand h1 { font-size: 18px; font-weight: 700; }
        .brand p { font-size: 11px; color: #94a3b8; }
        .status-badge {
          display: flex;
          align-items: center;
          gap: 6px;
          padding: 6px 12px;
          border-radius: 20px;
          font-size: 11px;
          font-weight: 600;
          background: rgba(30, 41, 59, 0.7);
          border: 1px solid rgba(255, 255, 255, 0.08);
        }
        .dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #ef4444;
          box-shadow: 0 0 8px #ef4444;
        }
        .dot.connected {
          background: #22c55e;
          box-shadow: 0 0 8px #22c55e;
        }
        .card {
          background: rgba(15, 23, 42, 0.75);
          backdrop-filter: blur(16px);
          -webkit-backdrop-filter: blur(16px);
          border: 1px solid rgba(255, 255, 255, 0.1);
          border-radius: 16px;
          padding: 18px;
          display: flex;
          flex-direction: column;
          gap: 14px;
          box-shadow: 0 8px 30px rgba(0,0,0,0.3);
        }
        .card-title {
          font-size: 13px;
          font-weight: 700;
          color: #94a3b8;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          display: flex;
          align-items: center;
          justify-content: space-between;
        }
        .pin-input {
          display: flex;
          gap: 8px;
          justify-content: center;
          margin: 10px 0;
        }
        .pin-input input {
          width: 50px;
          height: 56px;
          text-align: center;
          font-size: 24px;
          font-weight: 700;
          border-radius: 12px;
          border: 1px solid rgba(255, 255, 255, 0.15);
          background: rgba(30, 41, 59, 0.6);
          color: #fff;
        }
        .pin-input input:focus {
          border-color: #3b82f6;
          outline: none;
          box-shadow: 0 0 12px rgba(59, 130, 246, 0.5);
        }
        .btn-primary {
          padding: 12px 18px;
          border-radius: 12px;
          border: none;
          background: linear-gradient(135deg, #3b82f6, #2563eb);
          color: white;
          font-weight: 600;
          font-size: 14px;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          transition: transform 0.1s, opacity 0.2s;
        }
        .btn-primary:active { transform: scale(0.98); }
        .btn-secondary {
          padding: 10px 16px;
          border-radius: 10px;
          border: 1px solid rgba(255, 255, 255, 0.15);
          background: rgba(255, 255, 255, 0.06);
          color: #e2e8f0;
          font-weight: 600;
          font-size: 13px;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 6px;
        }
        .clipboard-box {
          background: rgba(0, 0, 0, 0.35);
          border: 1px solid rgba(255, 255, 255, 0.08);
          border-radius: 12px;
          padding: 14px;
          min-height: 80px;
          max-height: 180px;
          overflow-y: auto;
          font-size: 14px;
          line-height: 1.5;
          word-break: break-all;
          white-space: pre-wrap;
        }
        textarea.input-box {
          width: 100%;
          min-height: 80px;
          background: rgba(0, 0, 0, 0.35);
          border: 1px solid rgba(255, 255, 255, 0.15);
          border-radius: 12px;
          padding: 12px;
          color: #fff;
          font-size: 14px;
          resize: vertical;
          outline: none;
        }
        textarea.input-box:focus { border-color: #3b82f6; }
        .hidden { display: none !important; }
        .success-toast {
          position: fixed;
          bottom: 24px;
          background: #22c55e;
          color: #fff;
          font-weight: 600;
          padding: 10px 20px;
          border-radius: 30px;
          font-size: 13px;
          box-shadow: 0 8px 24px rgba(34, 197, 94, 0.4);
          transform: translateY(100px);
          transition: transform 0.3s cubic-bezier(0.18, 0.89, 0.32, 1.28);
          z-index: 1000;
        }
        .success-toast.show { transform: translateY(0); }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="brand">
            <div class="logo">🌉</div>
            <div>
              <h1>AirBridge</h1>
              <p>Universal Wireless Clipboard</p>
            </div>
          </div>
          <div class="status-badge">
            <span class="dot" id="connDot"></span>
            <span id="connLabel">Connecting</span>
          </div>
        </div>

        <!-- Pairing Section -->
        <div class="card" id="pairCard">
          <div class="card-title">Device Pairing</div>
          <p style="font-size: 13px; color: #94a3b8;">Enter the 4-digit PIN shown on your Mac Menu Bar to connect securely.</p>
          <div class="pin-input">
            <input type="tel" maxlength="1" class="pin-digit" id="p1" autofocus>
            <input type="tel" maxlength="1" class="pin-digit" id="p2">
            <input type="tel" maxlength="1" class="pin-digit" id="p3">
            <input type="tel" maxlength="1" class="pin-digit" id="p4">
          </div>
          <button class="btn-primary" onclick="submitPairing()">Connect Device</button>
        </div>

        <!-- Active Clipboard Section -->
        <div class="card hidden" id="mainCard">
          <div class="card-title">
            <span>Mac Clipboard Content</span>
            <span id="clipTime" style="font-size: 11px; font-weight: normal; color: #64748b;">Just now</span>
          </div>
          <div class="clipboard-box" id="clipContent">Waiting for clipboard item...</div>
          <div style="display: flex; gap: 8px;">
            <button class="btn-primary" style="flex: 1;" onclick="copyCurrentToPhone()">
              📋 Copy to This Device
            </button>
          </div>
        </div>

        <!-- Send Text to Mac Section -->
        <div class="card hidden" id="sendCard">
          <div class="card-title">Send to Mac Clipboard</div>
          <textarea class="input-box" id="sendText" placeholder="Type or paste text here to push to your Mac..."></textarea>
          <button class="btn-primary" onclick="sendToMac()">🚀 Push to Mac (Cmd + V)</button>
        </div>

        <!-- File Transfer Section -->
        <div class="card hidden" id="fileCard">
          <div class="card-title">Send File / Photo to Mac</div>
          <input type="file" id="filePicker" style="display: none;" onchange="handleFileSelected(event)">
          <button class="btn-secondary" onclick="document.getElementById('filePicker').click()">
            📎 Choose Photo or File
          </button>
          <p id="fileStatus" style="font-size: 12px; color: #94a3b8; text-align: center;"></p>
        </div>
      </div>

      <div class="success-toast" id="toast">Copied to device!</div>

      <script>
        let token = localStorage.getItem('airbridge_token') || '';
        let ws;

        const pInputs = [document.getElementById('p1'), document.getElementById('p2'), document.getElementById('p3'), document.getElementById('p4')];
        pInputs.forEach((inp, idx) => {
          inp.addEventListener('input', (e) => {
            if (e.target.value.length === 1 && idx < 3) pInputs[idx + 1].focus();
          });
          inp.addEventListener('keydown', (e) => {
            if (e.key === 'Backspace' && !e.target.value && idx > 0) pInputs[idx - 1].focus();
          });
        });

        function showToast(msg) {
          const t = document.getElementById('toast');
          t.innerText = msg;
          t.classList.add('show');
          setTimeout(() => t.classList.remove('show'), 2200);
        }

        async function submitPairing() {
          const pin = pInputs.map(i => i.value).join('');
          if (pin.length !== 4) return alert('Please enter 4 digits');
          try {
            const res = await fetch('/api/pair', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ pin: pin, deviceName: navigator.userAgent.slice(0, 30), deviceType: 'Mobile' })
            });
            const data = await res.json();
            if (data.authorized) {
              token = data.token;
              localStorage.setItem('airbridge_token', token);
              showMainUI();
              initWebSocket();
            } else {
              alert('Invalid PIN. Please check Mac Menu Bar.');
            }
          } catch (e) {
            alert('Connection failed: ' + e.message);
          }
        }

        function showMainUI() {
          document.getElementById('pairCard').classList.add('hidden');
          document.getElementById('mainCard').classList.remove('hidden');
          document.getElementById('sendCard').classList.remove('hidden');
          document.getElementById('fileCard').classList.remove('hidden');
        }

        function initWebSocket() {
          if (!token) return;
          const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
          ws = new WebSocket(`${proto}//${location.host}/ws?token=${token}`);

          ws.onopen = () => {
            document.getElementById('connDot').className = 'dot connected';
            document.getElementById('connLabel').innerText = 'Connected';
            showMainUI();
          };

          ws.onmessage = (event) => {
            try {
              const item = JSON.parse(event.data);
              if (item.type === 'image') {
                document.getElementById('clipContent').innerHTML = `<img src="data:image/png;base64,${item.content}" style="max-width: 100%; border-radius: 8px;">`;
              } else {
                document.getElementById('clipContent').innerText = item.content;
              }
              document.getElementById('clipTime').innerText = new Date(item.timestamp).toLocaleTimeString();
            } catch (err) {}
          };

          ws.onclose = () => {
            document.getElementById('connDot').className = 'dot';
            document.getElementById('connLabel').innerText = 'Reconnecting';
            setTimeout(initWebSocket, 2000);
          };
        }

        function copyCurrentToPhone() {
          const text = document.getElementById('clipContent').innerText;
          navigator.clipboard.writeText(text).then(() => {
            showToast('✅ Copied to Phone Clipboard!');
          }).catch(() => {
            showToast('Copied!');
          });
        }

        async function sendToMac() {
          const text = document.getElementById('sendText').value;
          if (!text.trim()) return;
          try {
            await fetch('/api/clipboard', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
              body: JSON.stringify({ type: 'text', content: text })
            });
            document.getElementById('sendText').value = '';
            showToast('🚀 Pushed to Mac!');
          } catch (e) {
            alert('Failed: ' + e.message);
          }
        }

        async function handleFileSelected(e) {
          const file = e.target.files[0];
          if (!file) return;
          const status = document.getElementById('fileStatus');
          status.innerText = `Uploading ${file.name}...`;

          const formData = new FormData();
          formData.append('file', file);
          try {
            await fetch('/api/upload', {
              method: 'POST',
              headers: { 'Authorization': `Bearer ${token}` },
              body: formData
            });
            status.innerText = `✅ Sent ${file.name} to Mac!`;
            showToast('Sent to Mac Downloads!');
          } catch (err) {
            status.innerText = `Failed: ${err.message}`;
          }
        }

        if (token) {
          initWebSocket();
        }
      </script>
    </body>
    </html>
    """
}
