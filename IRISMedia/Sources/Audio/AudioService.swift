import AVFoundation

@MainActor
public class AudioService: NSObject, ObservableObject {
    public override init() {
        super.init()
    }

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var healthCheckTimer: Timer?

    @Published public var isListening = false
    @Published public var voiceActivityDetected = false
    @Published public var audioLevel: Float = 0

    // Adaptive VAD: tracks ambient noise floor and triggers only on significant voice
    private var ambientNoiseLevel: Float = 0.0
    private let ambientSmoothingFactor: Float = 0.995  // Slow adaptation (~5s window)
    private let voiceToNoiseRatio: Float = 2.5          // Voice must be 2.5x above ambient
    private let minimumThreshold: Float = 0.012         // Absolute floor threshold
    private var ambientCalibrated = false
    private var calibrationFrames = 0
    private let calibrationPeriod = 30  // ~0.7s calibration at startup

    private var silenceFrameCount = 0
    private var maxSilenceFrames = 30   // ~0.7s at 1024 buffer / 44.1kHz
    private var lastUILevelPublishNanos: UInt64 = 0
    private let levelPublishIntervalNanos: UInt64 = 50_000_000 // 20 Hz UI updates max

    public var onVoiceStart: (() -> Void)?
    public var onVoiceEnd: (() -> Void)?
    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    /// Called directly from audio thread with (level, isVoiceActive). Use for immediate UI feedback.
    public var onAudioLevelUpdate: ((Float, Bool) -> Void)?

    public func start() async throws {
        print("🎤 AudioService: Starting...")
        guard await checkPermission() else {
            print("❌ AudioService: Permission denied")
            throw AudioError.permissionDenied
        }

        print("🎤 AudioService: Creating engine...")
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        print("🎤 AudioService: Input format: \(format)")

        // Reset calibration state
        ambientNoiseLevel = 0.0
        ambientCalibrated = false
        calibrationFrames = 0

        print("🎤 AudioService: Installing tap...")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        // Setup interruption observer to detect when audio engine stops
        setupInterruptionObserver(for: engine)

        print("🎤 AudioService: Starting engine...")
        try engine.start()

        self.audioEngine = engine
        self.inputNode = inputNode
        isListening = true

        // Start health check timer (every 5 seconds)
        startHealthCheckTimer()

        print("✅ AudioService: Started successfully")
    }

    private func startHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Check if engine is running
            if let engine = self.audioEngine, !engine.isRunning {
                print("⚠️ AudioService: Health check failed - engine not running")
                Task { @MainActor in
                    do {
                        print("🔄 AudioService: Attempting automatic restart...")
                        try await self.start()
                    } catch {
                        print("❌ AudioService: Auto-restart failed: \(error)")
                    }
                }
            }
        }
    }

    private func setupInterruptionObserver(for engine: AVAudioEngine) {
        // Monitor for engine configuration changes (e.g., device disconnects, system audio changes)
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("⚠️ AudioService: Engine configuration changed")

            // Check if engine is still running
            if !engine.isRunning {
                print("🔄 AudioService: Engine stopped unexpectedly, restarting...")
                Task { @MainActor in
                    do {
                        // Remove old tap
                        self.inputNode?.removeTap(onBus: 0)

                        // Restart engine
                        try await self.start()
                        print("✅ AudioService: Engine restarted successfully")
                    } catch {
                        print("❌ AudioService: Failed to restart engine: \(error)")
                    }
                }
            }
        }
    }

    public func stop() {
        print("🔇 AudioService: Stopping engine and removing tap")
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        inputNode = nil
        audioEngine = nil
        isListening = false
        voiceActivityDetected = false
        isVoiceActiveInternal = false
        silenceFrameCount = 0
        NotificationCenter.default.removeObserver(self)
    }

    private var isVoiceActiveInternal = false

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let level = sum / Float(frameLength)

        // Calibration phase: learn the ambient noise floor before detecting voice
        if !ambientCalibrated {
            calibrationFrames += 1
            if calibrationFrames <= calibrationPeriod {
                // Running average during calibration
                ambientNoiseLevel = ambientNoiseLevel + (level - ambientNoiseLevel) / Float(calibrationFrames)
                // Forward buffers but don't detect voice yet
                onAudioBuffer?(buffer)
                maybePublishAudioLevelToUI(level: level, force: calibrationFrames <= 2)
                return
            } else {
                ambientCalibrated = true
                print("🎤 AudioService: Ambient noise calibrated at \(String(format: "%.4f", ambientNoiseLevel))")
            }
        }

        // Update ambient noise estimate (only when NOT in voice activity)
        if !isVoiceActiveInternal {
            ambientNoiseLevel = ambientNoiseLevel * ambientSmoothingFactor + level * (1 - ambientSmoothingFactor)
        }

        // Dynamic threshold: max of minimum floor and voiceToNoiseRatio × ambient
        let dynamicThreshold = max(minimumThreshold, ambientNoiseLevel * voiceToNoiseRatio)

        // Detect voice activity change
        var voiceStarted = false
        var voiceEnded = false

        if level > dynamicThreshold {
            if !self.isVoiceActiveInternal {
                self.isVoiceActiveInternal = true
                voiceStarted = true
                print("🎤 VAD: Voice START (level=\(String(format: "%.4f", level)), threshold=\(String(format: "%.4f", dynamicThreshold)), ambient=\(String(format: "%.4f", ambientNoiseLevel)))")
            }
            self.silenceFrameCount = 0
        } else if self.isVoiceActiveInternal {
            self.silenceFrameCount += 1
            if self.silenceFrameCount > self.maxSilenceFrames {
                self.isVoiceActiveInternal = false
                voiceEnded = true
                print("🔇 VAD: Voice END (silence for \(self.silenceFrameCount) frames)")
            }
        }

        // Direct callback from audio thread for immediate UI feedback
        onAudioLevelUpdate?(level, isVoiceActiveInternal)

        let shouldPublishLevel = shouldPublishLevelUpdate(force: voiceStarted || voiceEnded)
        if shouldPublishLevel || voiceStarted || voiceEnded {
            // Dispatch UI updates and callbacks to MainActor
            Task { @MainActor in
                if shouldPublishLevel {
                    self.audioLevel = level
                }
                if voiceStarted {
                    self.voiceActivityDetected = true
                    self.onVoiceStart?()
                }
                if voiceEnded {
                    self.voiceActivityDetected = false
                    self.onVoiceEnd?()
                }
            }
        }

        // Always forward audio buffers — the Live API does its own server-side turn detection
        onAudioBuffer?(buffer)
    }

    private func checkPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    private func shouldPublishLevelUpdate(force: Bool) -> Bool {
        if force {
            lastUILevelPublishNanos = DispatchTime.now().uptimeNanoseconds
            return true
        }

        let now = DispatchTime.now().uptimeNanoseconds
        if now - lastUILevelPublishNanos >= levelPublishIntervalNanos {
            lastUILevelPublishNanos = now
            return true
        }
        return false
    }

    private func maybePublishAudioLevelToUI(level: Float, force: Bool) {
        guard shouldPublishLevelUpdate(force: force) else { return }
        Task { @MainActor in
            self.audioLevel = level
        }
    }
}

public enum AudioError: Error {
    case permissionDenied
}
