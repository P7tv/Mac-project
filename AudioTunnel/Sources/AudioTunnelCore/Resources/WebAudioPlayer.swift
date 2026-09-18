import Foundation

public enum WebAudioPlayer {
    public static let htmlContent: String = #"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>AudioTunnel — Low-Latency Mac Audio Bridge</title>
    <style>
        :root {
            --bg: #090d16;
            --card-bg: rgba(18, 24, 38, 0.8);
            --card-border: rgba(255, 255, 255, 0.1);
            --accent: #00f2fe;
            --accent-gradient: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            --text: #f0f4fc;
            --text-dim: #8b9bb4;
            --success: #10b981;
            --warning: #f59e0b;
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
                radial-gradient(circle at 15% 20%, rgba(79, 172, 254, 0.15) 0%, transparent 40%),
                radial-gradient(circle at 85% 80%, rgba(0, 242, 254, 0.12) 0%, transparent 40%);
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
            max-width: 480px;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 28px;
            padding: 32px 28px;
            backdrop-filter: blur(28px);
            -webkit-backdrop-filter: blur(28px);
            box-shadow: 0 24px 64px rgba(0, 0, 0, 0.55), inset 0 1px 1px rgba(255, 255, 255, 0.15);
            text-align: center;
        }

        .brand-header {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            margin-bottom: 6px;
        }

        .brand-icon {
            width: 44px;
            height: 44px;
            background: var(--accent-gradient);
            border-radius: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 8px 20px rgba(0, 242, 254, 0.35);
        }

        .brand-icon svg {
            width: 24px;
            height: 24px;
            fill: #fff;
        }

        h1 {
            font-size: 22px;
            font-weight: 700;
            letter-spacing: -0.5px;
        }

        .subtitle {
            color: var(--text-dim);
            font-size: 13px;
            margin-bottom: 18px;
        }

        .status-pill-group {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }

        .status-pill {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 5px 12px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 20px;
            font-size: 11.5px;
            font-weight: 500;
            color: var(--text-dim);
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
            box-shadow: 0 0 8px var(--success);
        }

        .engine-badge {
            background: rgba(0, 242, 254, 0.1);
            border: 1px solid rgba(0, 242, 254, 0.25);
            color: #00f2fe;
            border-radius: 20px;
            padding: 4px 10px;
            font-size: 11px;
            font-weight: 600;
        }

        /* Canvas Visualizer */
        .visualizer-wrapper {
            width: 100%;
            height: 85px;
            background: rgba(0, 0, 0, 0.3);
            border-radius: 16px;
            border: 1px solid rgba(255, 255, 255, 0.06);
            margin-bottom: 20px;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
        }

        canvas {
            width: 100%;
            height: 100%;
        }

        /* Play Button */
        .play-btn {
            width: 100%;
            padding: 15px;
            border-radius: 18px;
            border: none;
            background: var(--accent-gradient);
            color: #fff;
            font-size: 15px;
            font-weight: 600;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            box-shadow: 0 10px 24px rgba(0, 242, 254, 0.3);
            transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
            margin-bottom: 18px;
        }

        .play-btn:active {
            transform: scale(0.98);
        }

        .play-btn.playing {
            background: rgba(239, 68, 68, 0.16);
            border: 1px solid rgba(239, 68, 68, 0.35);
            color: #ff7070;
            box-shadow: none;
        }

        /* Latency Selector */
        .latency-section {
            margin-bottom: 18px;
            text-align: left;
        }

        .section-label {
            font-size: 11.5px;
            color: var(--text-dim);
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }

        .latency-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 8px;
        }

        .latency-btn {
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 12px;
            padding: 10px 6px;
            cursor: pointer;
            color: var(--text-dim);
            transition: all 0.2s ease;
            text-align: center;
        }

        .latency-btn.active {
            background: rgba(0, 242, 254, 0.15);
            border-color: rgba(0, 242, 254, 0.5);
            color: var(--text);
            box-shadow: 0 0 12px rgba(0, 242, 254, 0.2);
        }

        .latency-btn-title {
            font-size: 12px;
            font-weight: 600;
            margin-bottom: 2px;
        }

        .latency-btn-sub {
            font-size: 10px;
            opacity: 0.75;
        }

        /* Controls Card */
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
            margin-bottom: 10px;
        }

        .control-row:last-child {
            margin-bottom: 0;
        }

        .control-label {
            font-size: 12.5px;
            color: var(--text-dim);
            font-weight: 500;
        }

        .control-value {
            font-size: 12.5px;
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
            margin-top: 6px;
        }

        .slider::-webkit-slider-thumb {
            -webkit-appearance: none;
            appearance: none;
            width: 16px;
            height: 16px;
            border-radius: 50%;
            background: var(--accent);
            cursor: pointer;
            box-shadow: 0 0 8px rgba(0, 242, 254, 0.5);
        }

        .footer-info {
            margin-top: 18px;
            font-size: 11px;
            color: var(--text-dim);
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="brand-header">
            <div class="brand-icon">
                <svg viewBox="0 0 24 24">
                    <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/>
                </svg>
            </div>
            <h1>AudioTunnel</h1>
        </div>
        <p class="subtitle">Ultra-Low Latency Wireless Mac Audio Bridge</p>

        <div class="status-pill-group">
            <div class="status-pill">
                <div class="status-dot" id="statusDot"></div>
                <span id="statusText">Ready to connect</span>
            </div>
            <div class="engine-badge" id="engineBadge">AudioWorklet + RingBuffer</div>
            <div class="status-pill" id="bufferPill" style="display: none;">
                <span id="bufferText">0 ms buffer</span>
            </div>
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

        <div class="latency-section">
            <div class="section-label">Latency Mode</div>
            <div class="latency-grid">
                <button class="latency-btn" id="btnUltraLow" onclick="setLatencyProfile('ultraLow', 1200)">
                    <div class="latency-btn-title">⚡ Ultra-Low</div>
                    <div class="latency-btn-sub">~25 ms • Gaming</div>
                </button>
                <button class="latency-btn active" id="btnBalanced" onclick="setLatencyProfile('balanced', 2880)">
                    <div class="latency-btn-title">⚖️ Balanced</div>
                    <div class="latency-btn-sub">~60 ms • Default</div>
                </button>
                <button class="latency-btn" id="btnSmooth" onclick="setLatencyProfile('smooth', 5760)">
                    <div class="latency-btn-title">🛡️ Smooth</div>
                    <div class="latency-btn-sub">~120 ms • Wi-Fi</div>
                </button>
            </div>
        </div>

        <div class="controls-card">
            <div class="control-row">
                <span class="control-label">Volume</span>
                <span class="control-value" id="volVal">100%</span>
            </div>
            <input type="range" min="0" max="150" value="100" class="slider" id="volSlider" oninput="onVolumeChange(this.value)">

            <div class="control-row" style="margin-top: 12px;">
                <span class="control-label">Audio Stream</span>
                <span class="control-value">48 kHz • 16-bit Stereo</span>
            </div>
            <div class="control-row">
                <span class="control-label">Screen Wake Lock</span>
                <span class="control-value" id="wakeLockStatus">Inactive</span>
            </div>
        </div>

        <div class="footer-info">
            <span>Lock-Free RingBuffer</span>
            <span>•</span>
            <span>Clock Drift Correction</span>
            <span>•</span>
            <span>Zero Cloud</span>
        </div>
    </div>

    <script>
        // Inline AudioWorkletProcessor definition
        const workletCode = `
        class PCMPlayerProcessor extends AudioWorkletProcessor {
            constructor() {
                super();
                this.capacity = 96000; // 1 second @ 48kHz stereo
                this.bufferL = new Float32Array(this.capacity);
                this.bufferR = new Float32Array(this.capacity);
                this.writePtr = 0;
                this.readPtr = 0;
                this.bufferedFrames = 0;
                this.targetFrames = 2880; // default Balanced 60ms
                this.isBuffering = true;  // Wait until buffer reaches target to avoid initial stutter
                this.reportCounter = 0;

                this.port.onmessage = (e) => {
                    const msg = e.data;
                    if (msg.type === 'pcm') {
                        this.pushPCM(msg.left, msg.right);
                    } else if (msg.type === 'setTarget') {
                        this.targetFrames = msg.frames;
                    } else if (msg.type === 'reset') {
                        this.writePtr = 0;
                        this.readPtr = 0;
                        this.bufferedFrames = 0;
                        this.isBuffering = true;
                    }
                };
            }

            pushPCM(left, right) {
                const len = left.length;
                // Buffer overflow protection: drop oldest samples if backlog exceeds capacity
                if (this.bufferedFrames + len > this.capacity) {
                    const drop = (this.bufferedFrames + len) - this.capacity + 2400;
                    this.readPtr = (this.readPtr + drop) % this.capacity;
                    this.bufferedFrames = Math.max(0, this.bufferedFrames - drop);
                }

                for (let i = 0; i < len; i++) {
                    this.bufferL[this.writePtr] = left[i];
                    this.bufferR[this.writePtr] = right[i];
                    this.writePtr = (this.writePtr + 1) % this.capacity;
                }
                this.bufferedFrames += len;

                // End initial pre-buffering when target frames accumulated
                if (this.isBuffering && this.bufferedFrames >= this.targetFrames) {
                    this.isBuffering = false;
                }
            }

            process(inputs, outputs, parameters) {
                const output = outputs[0];
                const outL = output[0];
                const outR = output[1] || output[0];
                const quantum = outL.length; // 128 frames

                this.reportCounter++;
                if (this.reportCounter % 20 === 0) {
                    const ms = (this.bufferedFrames / 48000) * 1000;
                    this.port.postMessage({ type: 'metrics', ms: ms });
                }

                // If pre-buffering (first packet buildup), wait until target reached
                if (this.isBuffering) {
                    outL.fill(0);
                    outR.fill(0);
                    return true;
                }

                // If buffer is critically low (< quantum), output available and soft-fade remaining
                if (this.bufferedFrames < quantum) {
                    const available = this.bufferedFrames;
                    for (let i = 0; i < available; i++) {
                        const fade = (available - i) / available;
                        outL[i] = this.bufferL[this.readPtr] * fade;
                        outR[i] = this.bufferR[this.readPtr] * fade;
                        this.readPtr = (this.readPtr + 1) % this.capacity;
                    }
                    for (let i = available; i < quantum; i++) {
                        outL[i] = 0;
                        outR[i] = 0;
                    }
                    this.bufferedFrames = 0;
                    return true;
                }

                // Bidirectional smooth clock drift adjustment (ONCE per quantum)
                // If queue is running high (> target + 720 frames, ~15ms), consume 1 extra frame (~0.7% speedup)
                if (this.bufferedFrames > this.targetFrames + 720) {
                    this.readPtr = (this.readPtr + 1) % this.capacity;
                    this.bufferedFrames--;
                }
                // If queue is running low (< target - 720 frames, ~15ms) but safe, repeat 1 frame (~0.7% slowdown)
                else if (this.bufferedFrames < this.targetFrames - 720 && this.bufferedFrames > 256) {
                    this.readPtr = (this.readPtr - 1 + this.capacity) % this.capacity;
                    this.bufferedFrames++;
                }

                // Clean audio output
                for (let i = 0; i < quantum; i++) {
                    outL[i] = this.bufferL[this.readPtr];
                    outR[i] = this.bufferR[this.readPtr];
                    this.readPtr = (this.readPtr + 1) % this.capacity;
                }
                this.bufferedFrames -= quantum;

                return true;
            }
        }
        registerProcessor('pcm-player-worklet', PCMPlayerProcessor);
        `;

        let isPlaying = false;
        let audioCtx = null;
        let workletNode = null;
        let gainNode = null;
        let analyserNode = null;
        let ws = null;
        let wakeLock = null;
        let currentTargetFrames = 2880;

        const playBtn = document.getElementById('playBtn');
        const playBtnText = document.getElementById('playBtnText');
        const playIcon = document.getElementById('playIcon');
        const statusDot = document.getElementById('statusDot');
        const statusText = document.getElementById('statusText');
        const bufferPill = document.getElementById('bufferPill');
        const bufferText = document.getElementById('bufferText');
        const volVal = document.getElementById('volVal');
        const wakeLockStatus = document.getElementById('wakeLockStatus');
        const canvas = document.getElementById('visualizer');
        const canvasCtx = canvas.getContext('2d');

        function resizeCanvas() {
            canvas.width = canvas.parentElement.clientWidth * window.devicePixelRatio;
            canvas.height = canvas.parentElement.clientHeight * window.devicePixelRatio;
        }
        window.addEventListener('resize', resizeCanvas);
        resizeCanvas();

        function setLatencyProfile(mode, frames) {
            currentTargetFrames = frames;
            document.querySelectorAll('.latency-btn').forEach(btn => btn.classList.remove('active'));
            if (mode === 'ultraLow') document.getElementById('btnUltraLow').classList.add('active');
            else if (mode === 'balanced') document.getElementById('btnBalanced').classList.add('active');
            else if (mode === 'smooth') document.getElementById('btnSmooth').classList.add('active');

            if (workletNode) {
                workletNode.port.postMessage({ type: 'setTarget', frames: frames });
            }
        }

        async function requestWakeLock() {
            try {
                if ('wakeLock' in navigator) {
                    wakeLock = await navigator.wakeLock.request('screen');
                    wakeLockStatus.textContent = 'Active (Screen Awake)';
                    wakeLockStatus.style.color = '#10b981';
                    wakeLock.addEventListener('release', () => {
                        wakeLockStatus.textContent = 'Inactive';
                        wakeLockStatus.style.color = 'var(--text-dim)';
                    });
                }
            } catch (err) {
                console.warn('Wake Lock request error:', err);
                wakeLockStatus.textContent = 'Unsupported';
            }
        }

        function releaseWakeLock() {
            if (wakeLock) {
                wakeLock.release().catch(() => {});
                wakeLock = null;
                wakeLockStatus.textContent = 'Inactive';
                wakeLockStatus.style.color = 'var(--text-dim)';
            }
        }

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
                    audioCtx = new AudioContext({ sampleRate: 48000, latencyHint: 'interactive' });
                    
                    // Load AudioWorklet from Blob URL
                    const blob = new Blob([workletCode], { type: 'application/javascript' });
                    const blobUrl = URL.createObjectURL(blob);
                    await audioCtx.audioWorklet.addModule(blobUrl);

                    workletNode = new AudioWorkletNode(audioCtx, 'pcm-player-worklet', {
                        numberOfInputs: 0,
                        numberOfOutputs: 1,
                        outputChannelCount: [2]
                    });

                    workletNode.port.onmessage = (e) => {
                        if (e.data.type === 'metrics') {
                            const ms = Math.round(e.data.ms);
                            bufferPill.style.display = 'inline-flex';
                            bufferText.textContent = `${ms} ms buffer`;
                            if (ms > 150) {
                                bufferText.style.color = '#f59e0b';
                            } else {
                                bufferText.style.color = '#10b981';
                            }
                        }
                    };

                    gainNode = audioCtx.createGain();
                    analyserNode = audioCtx.createAnalyser();
                    analyserNode.fftSize = 64;

                    workletNode.connect(gainNode);
                    gainNode.connect(analyserNode);
                    analyserNode.connect(audioCtx.destination);
                }

                if (audioCtx.state === 'suspended') {
                    await audioCtx.resume();
                }

                workletNode.port.postMessage({ type: 'setTarget', frames: currentTargetFrames });
                connectWebSocket();
                requestWakeLock();

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
            releaseWakeLock();
            if (ws) {
                ws.close();
                ws = null;
            }
            if (workletNode) {
                workletNode.port.postMessage({ type: 'reset' });
            }
            playBtn.classList.remove('playing');
            playBtnText.textContent = 'Start Listening';
            playIcon.innerHTML = '<path d="M8 5v14l11-7z"/>';
            statusDot.classList.remove('connected');
            statusText.textContent = 'Disconnected';
            bufferPill.style.display = 'none';
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
            };

            ws.onmessage = (event) => {
                if (!isPlaying || !workletNode) return;
                const arrayBuffer = event.data;
                const int16View = new Int16Array(arrayBuffer);
                const numFrames = int16View.length / 2;
                if (numFrames === 0) return;

                const hwRate = (audioCtx && audioCtx.sampleRate) ? audioCtx.sampleRate : 48000;
                let left, right;

                if (Math.abs(hwRate - 48000) > 1.0) {
                    // Browser hardware runs at different sample rate (e.g. 44.1kHz on Bluetooth headsets)
                    const ratio = 48000.0 / hwRate;
                    const outFrames = Math.round(numFrames * hwRate / 48000.0);
                    left = new Float32Array(outFrames);
                    right = new Float32Array(outFrames);

                    for (let j = 0; j < outFrames; j++) {
                        const pos = Math.min(numFrames - 1, j * ratio);
                        const idx = Math.floor(pos);
                        const frac = pos - idx;
                        const nextIdx = Math.min(idx + 1, numFrames - 1);

                        const l1 = int16View[idx * 2] / 32768.0;
                        const l2 = int16View[nextIdx * 2] / 32768.0;
                        const r1 = int16View[idx * 2 + 1] / 32768.0;
                        const r2 = int16View[nextIdx * 2 + 1] / 32768.0;

                        left[j] = l1 * (1.0 - frac) + l2 * frac;
                        right[j] = r1 * (1.0 - frac) + r2 * frac;
                    }
                } else {
                    left = new Float32Array(numFrames);
                    right = new Float32Array(numFrames);
                    for (let i = 0; i < numFrames; i++) {
                        left[i] = int16View[i * 2] / 32768.0;
                        right[i] = int16View[i * 2 + 1] / 32768.0;
                    }
                }

                // Transfer memory directly to AudioWorklet (zero-copy)
                workletNode.port.postMessage(
                    { type: 'pcm', left: left, right: right },
                    [left.buffer, right.buffer]
                );
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
