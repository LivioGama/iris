import Foundation
import Combine
import AppKit
import IRISCore
import IRISVision
import IRISGaze
import IRISNetwork
import IRISMedia
import AVFoundation

extension String {
    func appendLine(to path: String) throws {
        let line = self + "\n"
        if let fileHandle = FileHandle(forWritingAtPath: path) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(line.data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            try line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

@MainActor
class IRISCoordinator: ObservableObject {
    // MARK: - Settings (Reactive)
    @Published var snapIndicatorToElement = false
    @Published var showGazeIndicator = true

    // MARK: - Camera Selection
    struct CameraInfo: Identifiable, Hashable {
        let id: Int          // index in AVFoundation discovery
        let name: String
        let score: Int
        let uniqueID: String
    }

    @Published var availableCameras: [CameraInfo] = []
    @Published var selectedCameraIndex: Int = UserDefaults.standard.integer(forKey: "IRIS_SELECTED_CAMERA") {
        didSet {
            UserDefaults.standard.set(selectedCameraIndex, forKey: "IRIS_SELECTED_CAMERA")
        }
    }

    // MARK: - Dependencies (Injected)

    private let container: DependencyContainer

    // Protocol-based providers (real or simulated)
    private let gazeProvider: GazeProvider
    private let aiProvider: AIProvider

    // Services accessed via container
    let cameraService: CameraService
    let gazeEstimator: GazeEstimator
    let audioService: IRISMedia.AudioService
    let speechService: SpeechService
    let screenCaptureService: IRISMedia.ScreenCaptureService
    let geminiAssistant: GeminiAssistantOrchestrator

    // MARK: - Published State

    @Published var isActive = false
    @Published var lastIntent: ResolvedIntent?
    @Published var debugLog: [String] = []
    @Published var isAccessibilityEnabled = false

    @Published var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @Published var gazeDebugInfo: String = ""
    @Published var shouldAcceptMouseEvents: Bool = false
    @Published var voiceDetected: Bool = false


    var currentScreen: NSScreen? = NSScreen.main {
        didSet {
            screenCaptureService.preferredScreen = currentScreen
            gazeEstimator.currentScreen = currentScreen
            geminiAssistant.setContinuousScreenCaptureScreen(currentScreen)
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var lastVoiceState = false
    private var lastActivityTime: Date?

    // MARK: - Initialization

    /// Dependency injection initializer
    init(container: DependencyContainer) {
        self.container = container

        // Inject all services from container FIRST
        self.cameraService = container.cameraService
        self.gazeEstimator = container.gazeEstimator
        self.audioService = container.audioService
        self.speechService = container.speechService
        self.screenCaptureService = container.screenCaptureService
        self.geminiAssistant = container.geminiAssistant

        // Initialize protocol-based providers (real or simulated) AFTER all services are set
        if SimulationConfig.useSimulation {
            self.gazeProvider = SimulatedGazeProvider()
            self.aiProvider = SimulatedAIProvider()
            let msg = "🎮 SIMULATION MODE ENABLED - Using simulated gaze and AI"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_startup.log")
        } else {
            self.gazeProvider = gazeEstimator
            self.aiProvider = geminiAssistant
            let msg = "🔴 REAL MODE - Using actual gaze tracker and Gemini API"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_startup.log")
        }

        // NOW we can safely initialize gaze estimator with current screen
        self.gazeEstimator.currentScreen = currentScreen

        // Setup all bindings
        setupBindings()
    }

    /// Legacy initializer for backward compatibility (will be deprecated)
    convenience init() {
        self.init(container: .shared)
    }

    private func setupBindings() {
        // Monitor Gemini response to enable/disable mouse events for close button and chat messages
        Publishers.CombineLatest3(
            geminiAssistant.$geminiResponse,
            geminiAssistant.$chatMessages,
            geminiAssistant.$capturedScreenshot
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] response, chatMessages, screenshot in
            // Accept mouse events when overlay is active (screenshot captured or messages present)
            self?.shouldAcceptMouseEvents = screenshot != nil || !chatMessages.isEmpty || !response.isEmpty
        }
        .store(in: &cancellables)

        // Direct audio callback from audio thread — publish only on voice-state transitions.
        var lastVoiceState = false
        audioService.onAudioLevelUpdate = { [weak self] _, isVoice in
            guard isVoice != lastVoiceState else { return }
            lastVoiceState = isVoice
            DispatchQueue.main.async {
                self?.voiceDetected = isVoice
            }
        }

        // Keep gaze tracking active at all times - user needs to see where they're looking
        // We only control whether background voice intents are processed based on Gemini state

        gazeEstimator.$gazePoint
            .sink { [weak self] point in
                self?.gazePoint = point
            }
            .store(in: &cancellables)

        gazeEstimator.$debugInfo
            .receive(on: RunLoop.main)
            .sink { [weak self] info in
                self?.gazeDebugInfo = info
            }
            .store(in: &cancellables)

        gazeEstimator.onRealTimeDetection = { [weak self] element in
            self?.log("RT: \(element.label)")
        }

        gazeEstimator.onGazeUpdate = { [weak self] gazePoint in
            // Real-time detection is now handled inside GazeEstimator at 30 FPS
            // No need for duplicate detection here
        }


        // VAD callbacks — kept for UI feedback (voiceDetected indicator) only.
        // With continuous screen sharing, Gemini Live handles turn detection server-side.
        // No need to trigger handleVoiceStart/handleVoiceEnd — audio streams continuously.
        audioService.onVoiceStart = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("🎤 IRISCoordinator: Voice activity detected")
            }
        }

        audioService.onVoiceEnd = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("🔇 IRISCoordinator: Voice activity ended")
            }
        }

        // Disabled old background voice recognition - now only using overlay-based system
        // audioService.onVoiceStart = { [weak self] in
        //     Task { @MainActor in
        //         self?.intentTrigger.voiceStarted()
        //         try? self?.speechService.startRecognition()
        //         self?.log("Voice started - listening...")
        //     }
        // }

        // audioService.onVoiceEnd = { [weak self] in
        //     Task { @MainActor in
        //         guard let self = self else { return }
        //         let transcript = self.speechService.transcript
        //         self.speechService.stopRecognition()
        //         self.intentTrigger.voiceEnded(transcript: transcript)
        //         self.log("Voice ended: \(transcript)")
        //     }
        // }

        audioService.onAudioBuffer = { [weak self] buffer in
            guard let self = self else { return }

            // 1. Always forward to Gemini — Live API encoder picks it up when session is active
            self.geminiAssistant.receiveAudioBuffer(buffer)

            // 2. Forward to background recognition only if Gemini is NOT active
            if !self.geminiAssistant.isListening && !self.geminiAssistant.isProcessing {
                self.speechService.appendBuffer(buffer)
            }
        }

    }

    func start() async {
        let logMsg = "🚀 IRISCoordinator.start() called"
        try? logMsg.write(toFile: "/tmp/iris_startup.log", atomically: true, encoding: .utf8)

        checkAccessibility()
        if !isAccessibilityEnabled {
            try? "⚠️ Accessibility not enabled".appendLine(to: "/tmp/iris_startup.log")
            requestAccessibilityPermission()
        } else {
            try? "✅ Accessibility enabled".appendLine(to: "/tmp/iris_startup.log")
        }

        do {
            // In simulation mode, skip real hardware startup
            if SimulationConfig.useSimulation {
                let simMsg = "🎮 SIMULATION MODE - Skipping real hardware initialization"
                print(simMsg)
                try? simMsg.appendLine(to: "/tmp/iris_startup.log")

                // Start simulated gaze provider
                if let simGaze = gazeProvider as? SimulatedGazeProvider {
                    simGaze.start()
                    try? "✅ Simulated gaze provider started".appendLine(to: "/tmp/iris_startup.log")
                }

                // Start simulated AI provider
                if let simAI = aiProvider as? SimulatedAIProvider {
                    simAI.startLiveSession()
                    try? "✅ Simulated AI provider started".appendLine(to: "/tmp/iris_startup.log")
                }

                isActive = true
                log("I.R.I.S activated - SIMULATION MODE")
                try? "✅ I.R.I.S activated (simulation)".appendLine(to: "/tmp/iris_startup.log")
                return
            }

            // REAL MODE: Initialize hardware
            try? "📡 Starting audio service...".appendLine(to: "/tmp/iris_startup.log")
            try await audioService.start()
            try? "✅ Audio service started".appendLine(to: "/tmp/iris_startup.log")

            // Ensure camera permission is requested and granted
            try? "📸 Requesting camera permission...".appendLine(to: "/tmp/iris_startup.log")
            _ = await AVCaptureDevice.requestAccess(for: .video)
            try? "📸 Camera permission request completed".appendLine(to: "/tmp/iris_startup.log")

            let resolvedCameraIndex = resolvePreferredGazeCameraIndex()
            let finalMsg = "📸 Final selected camera index (AVFoundation/OpenCV): \(resolvedCameraIndex)"
            print(finalMsg)
            try? finalMsg.appendLine(to: "/tmp/iris_startup.log")
            gazeEstimator.cameraIndex = resolvedCameraIndex

            try? "👁️ Starting gaze estimator...".appendLine(to: "/tmp/iris_startup.log")
            gazeEstimator.start()
            try? "✅ Gaze estimator started".appendLine(to: "/tmp/iris_startup.log")

            // Start Gemini Live session (WebSocket + continuous capture)
            try? "🌐 Starting Gemini Live session...".appendLine(to: "/tmp/iris_startup.log")
            geminiAssistant.startLiveSession()
            try? "✅ Gemini Live session started".appendLine(to: "/tmp/iris_startup.log")

            isActive = true
            log("I.R.I.S activated - Live API + Continuous Capture")
            try? "✅ I.R.I.S activated".appendLine(to: "/tmp/iris_startup.log")
        } catch {
            let errorMsg = "❌ Failed to start: \(error)"
            log(errorMsg)
            try? errorMsg.appendLine(to: "/tmp/iris_startup.log")
        }
    }

    private func resolvePreferredGazeCameraIndex() -> Int {
        // 1. Check for forced camera index via environment variable
        if let forced = ProcessInfo.processInfo.environment["IRIS_CAMERA_INDEX"],
           let forcedIndex = Int(forced),
           forcedIndex >= 0 {
            let msg = "📸 Using forced camera index from IRIS_CAMERA_INDEX=\(forcedIndex)"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_startup.log")
            return forcedIndex
        }

        // 2. Enumerate cameras via AVFoundation DiscoverySession
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        let devices = discoverySession.devices

        // Populate available cameras list for the settings picker
        var cameras: [CameraInfo] = []
        var bestIndex = 0
        var bestScore = -1

        let discoveredMsg = "📸 DiscoverySession found \(devices.count) cameras:"
        print(discoveredMsg)
        try? discoveredMsg.appendLine(to: "/tmp/iris_startup.log")

        for (index, device) in devices.enumerated() {
            let score = cameraPreferenceScore(device.localizedName)
            let msg = "📸 [\(index)] \(device.localizedName) (ID: \(device.uniqueID), Score: \(score))"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_startup.log")

            cameras.append(CameraInfo(id: index, name: device.localizedName, score: score, uniqueID: device.uniqueID))

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        availableCameras = cameras

        // 3. Skip persisted camera index — camera ordering changes between boots
        //    Always use score-based auto-selection for reliability

        // 4. Fall back to auto-selection by priority score
        selectedCameraIndex = bestIndex

        let bestDevice = bestIndex < devices.count ? devices[bestIndex] : nil
        let resultMsg = "✅ Auto-selected camera: [\(bestIndex)] \(bestDevice?.localizedName ?? "?") (Score: \(bestScore))"
        print(resultMsg)
        try? resultMsg.appendLine(to: "/tmp/iris_startup.log")

        return bestIndex
    }

    /// Returns a priority score for camera selection (higher = more preferred)
    /// Used to deterministically select between multiple matching cameras
    private func cameraPreferenceScore(_ name: String) -> Int {
        let normalized = name.lowercased()

        // Exclude desk view, virtual cameras, and VR cameras (score = -1)
        if normalized.contains("desk view") ||
           normalized.contains("capture screen") ||
           normalized.contains("obs virtual") ||
           normalized.contains("immersed") ||
           normalized.contains("virtual desktop") {
            return -1
        }

        // Priority 1: MacBook Pro built-in camera (score = 100)
        if normalized.contains("macbook pro camera") ||
           normalized.contains("macbook air camera") ||
           normalized.contains("facetime hd camera (built-in)") {
            return 100
        }

        // Priority 2: Logi Studio and Logitech professional cameras (score = 90)
        if normalized.contains("logi studio") {
            return 90
        }
        if normalized.contains("logi") || normalized.contains("logitech") {
            return 85
        }

        // Priority 3: Generic MacBook cameras (score = 70)
        if normalized.contains("macbook") {
            return 70
        }

        // Priority 4: Other FaceTime cameras (score = 50)
        if normalized.contains("facetime") {
            return 50
        }

        // Priority 5: External display cameras (score = 30)
        if normalized.contains("studio display") || normalized.contains("display camera") {
            return 30
        }

        // Unknown cameras (score = 0)
        return 0
    }

    /// Switch to a different camera at runtime
    func switchCamera(to index: Int) {
        guard index >= 0, index < availableCameras.count else { return }
        selectedCameraIndex = index
        gazeEstimator.cameraIndex = index
        gazeEstimator.restart()
        let msg = "📸 Switched to camera [\(index)] \(availableCameras[index].name)"
        print(msg)
        try? msg.appendLine(to: "/tmp/iris_startup.log")
    }

    func checkAccessibility() {
        isAccessibilityEnabled = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Poll for a few seconds to see if it was enabled
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            attempts += 1
            if AXIsProcessTrusted() {
                Task { @MainActor in
                    self?.isAccessibilityEnabled = true
                }
                timer.invalidate()
            } else if attempts > 30 {
                timer.invalidate()
            }
        }
    }

    func stop() {
        geminiAssistant.stopLiveSession()
        gazeEstimator.stop()
        audioService.stop()
        isActive = false
        log("I.R.I.S deactivated")
    }





    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog.append("[\(timestamp)] \(message)")
        if debugLog.count > 50 {
            debugLog.removeFirst()
        }
    }
}
