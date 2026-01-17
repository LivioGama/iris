import Foundation
import Combine
import AppKit
import IRISCore
import IRISVision
import IRISGaze
import IRISNetwork
import IRISMedia

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
    // MARK: - Dependencies (Injected)

    private let container: DependencyContainer

    // Services accessed via container
    let cameraService: CameraService
    let gazeEstimator: GazeEstimator
    let audioService: IRISMedia.AudioService
    let speechService: SpeechService
    let screenCaptureService: IRISMedia.ScreenCaptureService
    let intentTrigger: IntentTrigger
    let intentResolver: IntentResolver
    let contextualAnalysis: ContextualAnalysisService
    let geminiAssistant: GeminiAssistantOrchestrator

    // MARK: - Published State

    @Published var isActive = false
    @Published var currentState: IntentTrigger.State = .idle
    @Published var lastIntent: ResolvedIntent?
    @Published var debugLog: [String] = []
    @Published var isAccessibilityEnabled = false

    @Published var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @Published var gazeDebugInfo: String = ""
    @Published var shouldAcceptMouseEvents: Bool = false

    var currentScreen: NSScreen? = NSScreen.main {
        didSet {
            screenCaptureService.preferredScreen = currentScreen
            gazeEstimator.currentScreen = currentScreen
        }
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Dependency injection initializer
    init(container: DependencyContainer) {
        self.container = container

        // Inject all services from container
        self.cameraService = container.cameraService
        self.gazeEstimator = container.gazeEstimator
        self.audioService = container.audioService
        self.speechService = container.speechService
        self.screenCaptureService = container.screenCaptureService
        self.intentTrigger = container.intentTrigger
        self.intentResolver = container.intentResolver
        self.contextualAnalysis = container.contextualAnalysisService
        self.geminiAssistant = container.geminiAssistant

        // Initialize gaze estimator with current screen
        self.gazeEstimator.currentScreen = currentScreen

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

        // Keep gaze tracking active at all times - user needs to see where they're looking
        // We only control whether background voice intents are processed based on Gemini state

        gazeEstimator.$gazePoint
            .sink { [weak self] point in
                self?.gazePoint = point
                self?.intentTrigger.updateGaze(point)
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

        gazeEstimator.onHoverDetected = { [weak self] gazePoint in
            Task { @MainActor in
                await self?.performContextualAnalysis(at: gazePoint)
            }
        }

        gazeEstimator.onBlinkDetected = { [weak self] point, element in
            print("🎯 IRISCoordinator: onBlinkDetected callback triggered!")
            Task { @MainActor in
                guard let self = self else { return }

                // Trigger Gemini assistant (now uses continuous audio stream)
                print("🎯 IRISCoordinator: Calling geminiAssistant.handleBlink")
                self.geminiAssistant.handleBlink(at: point, focusedElement: element)
            }
        }
        print("✅ IRISCoordinator: Blink callback registered")

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

            // 1. Forward to Gemini (processes only if listening)
            self.geminiAssistant.receiveAudioBuffer(buffer)

            // 2. Forward to background recognition only if Gemini is NOT active
            if !self.geminiAssistant.isListening && !self.geminiAssistant.isProcessing {
                self.speechService.appendBuffer(buffer)
            }
        }

        intentTrigger.onTrigger = { [weak self] gazePoint, transcript in
            Task { @MainActor in
                await self?.processIntent(gazePoint: gazePoint, transcript: transcript)
            }
        }

        intentTrigger.$state
            .assign(to: &$currentState)
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
            try? "📡 Starting audio service...".appendLine(to: "/tmp/iris_startup.log")
            try await audioService.start()
            try? "✅ Audio service started".appendLine(to: "/tmp/iris_startup.log")

            try? "👁️ Starting gaze estimator...".appendLine(to: "/tmp/iris_startup.log")
            gazeEstimator.start()
            try? "✅ Gaze estimator started".appendLine(to: "/tmp/iris_startup.log")

            isActive = true
            log("I.R.I.S activated - EyeGestures Python")
            try? "✅ I.R.I.S activated".appendLine(to: "/tmp/iris_startup.log")
        } catch {
            let errorMsg = "❌ Failed to start: \(error)"
            log(errorMsg)
            try? errorMsg.appendLine(to: "/tmp/iris_startup.log")
        }
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
        gazeEstimator.stop()
        audioService.stop()
        isActive = false
        log("I.R.I.S deactivated")
    }

    private func performContextualAnalysis(at gazePoint: CGPoint) async {
        // Note: GazeEstimator already sets heavy processing mode when triggering hover
        do {
            let screenImage = try await screenCaptureService.captureScreen(at: gazePoint)

            let detectedElement = await contextualAnalysis.analyzeContext(
                around: gazePoint,
                screenImage: screenImage
            )

            if let element = detectedElement {
                Task { @MainActor in
                    self.gazeEstimator.detectedElement = element
                }
            }

        } catch {
            log("Contextual analysis failed: \(error)")
        }
    }



    private func processIntent(gazePoint: CGPoint, transcript: String) async {
        log("Processing intent at \(gazePoint)")

        // Enable low power mode during heavy intent processing
        gazeEstimator.setHeavyProcessing(true)
        defer {
            gazeEstimator.setHeavyProcessing(false)
        }

        do {
            let fullScreen = try await screenCaptureService.captureFullScreen()
            let cropped = try await screenCaptureService.captureCroppedRegion(around: gazePoint)

            guard let fullBase64 = screenCaptureService.imageToBase64(fullScreen),
                  let croppedBase64 = screenCaptureService.imageToBase64(cropped) else {
                log("Failed to encode images")
                intentTrigger.reset()
                return
            }

            let intent = try await intentResolver.resolve(
                fullScreenImage: fullBase64,
                croppedImage: croppedBase64,
                transcript: transcript,
                gazePoint: gazePoint
            )

            lastIntent = intent
            intentTrigger.resolved()
            log("Resolved: \(intent.action) on \(intent.target) (\(Int(intent.confidence * 100))%)")

        } catch {
            log("Resolution failed: \(error)")
            intentTrigger.reset()
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog.append("[\(timestamp)] \(message)")
        if debugLog.count > 50 {
            debugLog.removeFirst()
        }
    }
}
