// BPM Finder Logic

let audioContext;
let analyser;
let microphone;
let isListening = false;
let animationId;

// Beat Detection Variables
const bufferSize = 4096;
const historyBuffer = [];
const minPeakDistance = 20; // Frames ~ 0.3s
let framesSinceLastPeak = 0;
let lastPeakTime = 0;
let intervals = [];

const startBtn = document.getElementById('start-btn');
const statusText = document.getElementById('status-text');
const bpmValue = document.getElementById('bpm-value');
const bpmDisplay = document.getElementById('bpm-display');
const visualizerBars = document.querySelectorAll('.bar');

startBtn.addEventListener('click', toggleListening);

async function toggleListening() {
    if (isListening) {
        stopListening();
    } else {
        await startListening();
    }
}

async function startListening() {
    statusText.innerText = "Demande d'autorisation...";
    
    try {
        // 1. Web Audio Setup
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        
        audioContext = new (window.AudioContext || window.webkitAudioContext)();
        analyser = audioContext.createAnalyser();
        analyser.fftSize = 256; // Low resolution for visuals and basic energy
        
        microphone = audioContext.createMediaStreamSource(stream);
        microphone.connect(analyser); // Only connect to analyser, not destination (loudspeaker loopback)

        isListening = true;
        startBtn.innerText = "Arrêter";
        statusText.innerText = "Écoute en cours...";
        bpmDisplay.classList.add('active');

        processAudio();

    } catch (err) {
        console.error(err);
        await Ondes.UI.showToast({
            message: "Erreur d'accès au micro.",
            type: "error"
        });
        statusText.innerText = "Erreur technique";
    }
}

function stopListening() {
    isListening = false;
    startBtn.innerText = "Écouter";
    statusText.innerText = "Appuyez pour commencer";
    bpmDisplay.classList.remove('active');
    bpmValue.innerText = "--";
    intervals = [];
    
    if (microphone) {
        microphone.disconnect();
        microphone = null;
    }
    if (audioContext) {
        audioContext.close();
        audioContext = null;
    }
    cancelAnimationFrame(animationId);
    resetVisualizer();
}

function processAudio() {
    if (!isListening) return;

    const bufferLength = analyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    analyser.getByteFrequencyData(dataArray);

    // Update Visualizer
    updateVisualizer(dataArray);

    // Beat Detection (Simplified Energy Based)
    // Low pass filter effect by taking only lower frequencies
    let energy = 0;
    // Focus on bass frequencies (0-20ish bins depending on sample rate)
    for (let i = 0; i < 20; i++) {
        energy += dataArray[i];
    }
    energy = energy / 20;

    // Threshold logic
    const now = Date.now();
    
    // Dynamic threshold based on recent history would be better, 
    // but fixed high threshold works for loud distinct beats close to mic.
    // Let's refine: Beat if energy > local average * 1.3
    
    historyBuffer.push(energy);
    if (historyBuffer.length > 50) historyBuffer.shift();
    
    const avgEnergy = historyBuffer.reduce((a, b) => a + b, 0) / historyBuffer.length;
    
    // Simple Peak Detection
    if (energy > avgEnergy * 1.4 && energy > 100) {
        if (now - lastPeakTime > 300) { // Max 200 BPM (60000/200 = 300ms)
            onBeat(now);
            lastPeakTime = now;
        }
    }

    animationId = requestAnimationFrame(processAudio);
}

function onBeat(time) {
    // 1. Visual Feedback
    bpmDisplay.classList.add('pulse');
    setTimeout(() => bpmDisplay.classList.remove('pulse'), 100);

    // 2. Haptic Feedback (via Bridge)
    Ondes.Device.hapticFeedback('light');

    // 3. Calculate BPM
    if (intervals.length > 0) {
        const delta = time - (lastPeakTime || time);
        // Only accept realistic intervals (40 BPM to 220 BPM) -> 1500ms to 272ms
        // Note: 'delta' here is 0 if lastPeakTime updated just before call? No, logic above sets lastPeakTime AFTER onBeat.
        // wait, let's fix logic flow.
    }
    // We need the PREVIOUS time, not the one we just set.
    // Actually the logic above sets lastPeakTime = now AFTER calling onBeat. 
    // So 'lastPeakTime' is the PREVIOUS beat time.
    
    if (lastPeakTime !== 0) {
        const delta = time - lastPeakTime;
        intervals.push(delta);
        if (intervals.length > 10) intervals.shift(); // Keep last 10 intervals
        
        // Calculate average
        const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
        const bpm = Math.round(60000 / avgInterval);
        
        bpmValue.innerText = bpm;
    }
}

function updateVisualizer(dataArray) {
    // Map 5 bars to different freq ranges
    for (let i = 0; i < 5; i++) {
        // approximate bins
        const index = i * 4; 
        const value = dataArray[index];
        const height = (value / 255) * 30;
        visualizerBars[i].style.height = `${Math.max(5, height)}px`;
    }
}

function resetVisualizer() {
    visualizerBars.forEach(b => b.style.height = '5px');
}
