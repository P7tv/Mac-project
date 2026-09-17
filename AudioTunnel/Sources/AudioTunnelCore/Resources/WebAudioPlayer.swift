import Foundation

public enum WebAudioPlayer {
    public static let htmlContent: String = #"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AudioTunnel — Wireless Mac Audio Bridge</title>
    <style>
        :root {
            --bg: #090d16;
            --card-bg: rgba(18, 24, 38, 0.75);
            --card-border: rgba(255, 255, 255, 0.1);
            --accent: #00f2fe;
            --accent-gradient: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            --text: #f0f4fc;
            --text-dim: #8b9bb4;
            --success: #10b981;
            --danger: #ef4444;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            -webkit-user-select: none;
            user-select: none;
        }

        body {
            background: var(--bg);
            background-image: 
                radial-gradient(circle at 15% 20%, rgba(79, 172, 254, 0.12) 0%, transparent 40%),
                radial-gradient(circle at 85% 80%, rgba(0, 242, 254, 0.1) 0%, transparent 40%);
            color: var(--text);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .container {
            width: 100%;
            max-width: 460px;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 28px;
            padding: 32px 28px;
            backdrop-filter: blur(24px);
            -webkit-backdrop-filter: blur(24px);
            box-shadow: 0 24px 64px rgba(0, 0, 0, 0.5), inset 0 1px 1px rgba(255, 255, 255, 0.15);
            text-align: center;
        }

        .brand-icon {
            width: 68px;
            height: 68px;
            margin: 0 auto 18px;
            background: var(--accent-gradient);
            border-radius: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 10px 25px rgba(0, 242, 254, 0.35);
        }

        .brand-icon svg {
            width: 36px;
            height: 36px;
            fill: #fff;
        }

        h1 {
            font-size: 24px;
            font-weight: 700;
            letter-spacing: -0.5px;
            margin-bottom: 6px;
        }

        .subtitle {
            color: var(--text-dim);
            font-size: 13.5px;
            margin-bottom: 24px;
        }

        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 6px 14px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 20px;
            font-size: 12.5px;
            font-weight: 500;
            color: var(--text-dim);
            margin-bottom: 24px;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--danger);
            transition: background 0.3s ease;
        }

        .status-dot.connected {
            background: var(--success);
            box-shadow: 0 0 10px var(--success);
        }

        /* Canvas Visualizer */
        .visualizer-wrapper {
            width: 100%;
            height: 90px;
            background: rgba(0, 0, 0, 0.25);
            border-radius: 16px;
            border: 1px solid rgba(255, 255, 255, 0.05);
            margin-bottom: 24px;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        canvas {
            width: 100%;
            height: 100%;
        }

        /* Play Button */
        .play-btn {
            width: 100%;
            padding: 16px;
            border-radius: 18px;
            border: none;
            background: var(--accent-gradient);
            color: #fff;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            box-shadow: 0 12px 28px rgba(0, 242, 254, 0.3);
            transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
            margin-bottom: 20px;
        }

        .play-btn:active {
            transform: scale(0.98);
        }

        .play-btn.playing {
            background: rgba(239, 68, 68, 0.15);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: #ff6b6b;
            box-shadow: none;
        }

        /* Controls Slider */
        .controls-card {
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 18px;
            padding: 16px 20px;
            text-align: left;
        }

        .control-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 12px;
        }

        .control-row:last-child {
            margin-bottom: 0;
        }

        .control-label {
            font-size: 13px;
            color: var(--text-dim);
            font-weight: 500;
        }

        .control-value {
            font-size: 13px;
            color: var(--text);
            font-weight: 600;
        }

        .slider {
            -webkit-appearance: none;
            width: 100%;
            height: 6px;
            border-radius: 3px;
            background: rgba(255, 255, 255, 0.12);
            outline: none;
            margin-top: 8px;
        }

        .slider::-webkit-slider-thumb {
            -webkit-appearance: none;
            appearance: none;
            width: 18px;
            height: 18px;
            border-radius: 50%;
            background: var(--accent);
            cursor: pointer;
            box-shadow: 0 0 10px rgba(0, 242, 254, 0.5);
        }

        .footer-info {
            margin-top: 20px;
            font-size: 11.5px;
            color: var(--text-dim);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="brand-icon">
            <svg viewBox="0 0 24 24">
                <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/>
            </svg>
        </div>
        <h1>AudioTunnel</h1>
        <p class="subtitle">Stream Mac System Audio & Mic to any browser</p>

        <div class="status-pill">
            <div class="status-dot" id="statusDot"></div>
            <span id="statusText">Ready to connect</span>
        </div>

        <div class="visualizer-wrapper">
            <canvas id="visualizer"></canvas>
        </div>

        <button class="play-btn" id="playBtn" onclick="toggleAudio()">
            <svg id="playIcon" width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M8 5v14l11-7z"/>
            </svg>
            <span id="playBtnText">Start Listening</span>
        </button>

        <div class="controls-card">
            <div class="control-row">
                <span class="control-label">Volume</span>
                <span class="control-value" id="volVal">100%</span>
            </div>
            <input type="range" min="0" max="150" value="100" class="slider" id="volSlider" oninput="onVolumeChange(this.value)">

            <div class="control-row" style="margin-top: 14px;">
                <span class="control-label">Audio Quality</span>
                <span class="control-value">48 kHz • 16-bit Stereo</span>
            </div>
        </div>

        <div class="footer-info">
            Sub-millisecond local wireless bridge • Zero cloud
        </div>
    </div>

    <script>
        let isPlaying = false;
        let audioCtx = null;
        let gainNode = null;
        let analyserNode = null;
        let ws = null;
        let nextStartTime = 0;
        const sampleRate = 48000;
        const channels = 2;

        const playBtn = document.getElementById('playBtn');
        const playBtnText = document.getElementById('playBtnText');
        const playIcon = document.getElementById('playIcon');
        const statusDot = document.getElementById('statusDot');
        const statusText = document.getElementById('statusText');
        const volVal = document.getElementById('volVal');
        const canvas = document.getElementById('visualizer');
        const canvasCtx = canvas.getContext('2d');

        function resizeCanvas() {
            canvas.width = canvas.parentElement.clientWidth * window.devicePixelRatio;
            canvas.height = canvas.parentElement.clientHeight * window.devicePixelRatio;
        }
        window.addEventListener('resize', resizeCanvas);
        resizeCanvas();

        function toggleAudio() {
            if (isPlaying) {
                stopAudio();
            } else {
                startAudio();
            }
        }

        async function startAudio() {
            try {
                if (!audioCtx) {
                    const AudioContext = window.AudioContext || window.webkitAudioContext;
                    audioCtx = new AudioContext({ sampleRate: sampleRate, latencyHint: 'interactive' });
                    gainNode = audioCtx.createGain();
                    analyserNode = audioCtx.createAnalyser();
                    analyserNode.fftSize = 64;
                    gainNode.connect(analyserNode);
                    analyserNode.connect(audioCtx.destination);
                }

                if (audioCtx.state === 'suspended') {
                    await audioCtx.resume();
                }

                connectWebSocket();
                isPlaying = true;
                playBtn.classList.add('playing');
                playBtnText.textContent = 'Stop Listening';
                playIcon.innerHTML = '<path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>';
                drawVisualizer();
            } catch (e) {
                console.error("Audio init error:", e);
                statusText.textContent = 'Audio blocked by browser';
            }
        }

        function stopAudio() {
            isPlaying = false;
            if (ws) {
                ws.close();
                ws = null;
            }
            playBtn.classList.remove('playing');
            playBtnText.textContent = 'Start Listening';
            playIcon.innerHTML = '<path d="M8 5v14l11-7z"/>';
            statusDot.classList.remove('connected');
            statusText.textContent = 'Disconnected';
            nextStartTime = 0;
        }

        function connectWebSocket() {
            const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
            const url = `${proto}//${location.host}/audio`;
            statusText.textContent = 'Connecting...';

            ws = new WebSocket(url);
            ws.binaryType = 'arraybuffer';

            ws.onopen = () => {
                statusDot.classList.add('connected');
                statusText.textContent = 'Live Audio Connected';
                nextStartTime = audioCtx.currentTime + 0.05; // 50ms initial jitter buffer
            };

            ws.onmessage = (event) => {
                if (!isPlaying || !audioCtx) return;
                const arrayBuffer = event.data;
                playPCMChunk(arrayBuffer);
            };

            ws.onclose = () => {
                if (isPlaying) {
                    statusDot.classList.remove('connected');
                    statusText.textContent = 'Reconnecting in 2s...';
                    setTimeout(() => {
                        if (isPlaying) connectWebSocket();
                    }, 2000);
                }
            };

            ws.onerror = (err) => {
                console.error("WebSocket error:", err);
            };
        }

        function playPCMChunk(arrayBuffer) {
            const int16View = new Int16Array(arrayBuffer);
            const numFrames = int16View.length / channels;
            if (numFrames === 0) return;

            const audioBuffer = audioCtx.createBuffer(channels, numFrames, sampleRate);
            const leftChannel = audioBuffer.getChannelData(0);
            const rightChannel = audioBuffer.getChannelData(1);

            for (let i = 0; i < numFrames; i++) {
                leftChannel[i] = int16View[i * 2] / 32768.0;
                rightChannel[i] = int16View[i * 2 + 1] / 32768.0;
            }

            const source = audioCtx.createBufferSource();
            source.buffer = audioBuffer;
            source.connect(gainNode);

            const currentTime = audioCtx.currentTime;
            if (nextStartTime < currentTime) {
                nextStartTime = currentTime + 0.02; // re-sync if lagging
            }

            source.start(nextStartTime);
            nextStartTime += audioBuffer.duration;
        }

        function onVolumeChange(val) {
            volVal.textContent = val + '%';
            if (gainNode) {
                gainNode.gain.value = (val / 100.0);
            }
        }

        function drawVisualizer() {
            if (!isPlaying) {
                canvasCtx.clearRect(0, 0, canvas.width, canvas.height);
                return;
            }
            requestAnimationFrame(drawVisualizer);

            const bufferLength = analyserNode.frequencyBinCount;
            const dataArray = new Uint8Array(bufferLength);
            analyserNode.getByteFrequencyData(dataArray);

            canvasCtx.clearRect(0, 0, canvas.width, canvas.height);

            const barWidth = (canvas.width / bufferLength) * 1.8;
            let x = 0;

            for (let i = 0; i < bufferLength; i++) {
                const barHeight = (dataArray[i] / 255.0) * (canvas.height * 0.85);

                const grad = canvasCtx.createLinearGradient(0, canvas.height, 0, 0);
                grad.addColorStop(0, '#4facfe');
                grad.addColorStop(1, '#00f2fe');

                canvasCtx.fillStyle = grad;
                canvasCtx.fillRect(x, canvas.height - barHeight, barWidth - 2, barHeight);

                x += barWidth + 2;
            }
        }
    </script>
</body>
</html>
"""#
}
