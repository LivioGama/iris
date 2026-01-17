import Foundation
import Combine
import AppKit
import IRISCore
import IRISVision
import IRISGaze
import IRISNetwork
import IRISMedia

@MainActor
class IRISCoordinator: ObservableObject {
    let cameraService = CameraService()
    let gazeEstimator = GazeEstimator()
    let audioService = AudioService()
    let speechService = SpeechService()
    let screenCaptureService = ScreenCaptureService()
    let intentTrigger = IntentTrigger()
    let intentResolver = IntentResolver()
    let contextualAnalysis = ContextualAnalysisService()
    let geminiAssistant = GeminiAssistantOrchestrator()

    @Published var isActive = false
    @Published var currentState: IntentTrigger.State = .idle
    @Published var lastIntent: ResolvedIntent?
    @Published var debugLog: [String] = []

    @Published var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @Published var gazeDebugInfo: String = ""
    @Published var shouldAcceptMouseEvents: Bool = false

    var currentScreen: NSScreen? = NSScreen.main {
        didSet {
            screenCaptureService.preferredScreen = currentScreen
        }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Monitor Gemini response to enable/disable mouse events for close button and chat messages
        Publishers.CombineLatest(
            geminiAssistant.$geminiResponse,
            geminiAssistant.$chatMessages
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] response, chatMessages in
            self?.shouldAcceptMouseEvents = !response.isEmpty || !chatMessages.isEmpty
        }
        .store(in: &cancellables)

        // Disable tracking when listening, processing, or response is showing
        Publishers.CombineLatest4(
            geminiAssistant.$isListening,
            geminiAssistant.$isProcessing,
            geminiAssistant.$geminiResponse,
            geminiAssistant.$chatMessages
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isListening, isProcessing, response, chatMessages in
            let shouldDisableTracking = isListening || isProcessing || !response.isEmpty || !chatMessages.isEmpty
            self?.gazeEstimator.isTrackingEnabled = !shouldDisableTracking
        }
        .store(in: &cancellables)

        gazeEstimator.$gazePoint
            .receive(on: RunLoop.main)
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
            Task { @MainActor in
                self?.geminiAssistant.handleBlink(at: point, focusedElement: element)
            }
        }

        audioService.onVoiceStart = { [weak self] in
            Task { @MainActor in
                self?.intentTrigger.voiceStarted()
                try? self?.speechService.startRecognition()
                self?.log("Voice started - listening...")
            }
        }

        audioService.onVoiceEnd = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                let transcript = self.speechService.transcript
                self.speechService.stopRecognition()
                self.intentTrigger.voiceEnded(transcript: transcript)
                self.log("Voice ended: \(transcript)")
            }
        }

        audioService.onAudioBuffer = { [weak self] buffer in
            self?.speechService.appendBuffer(buffer)
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
        do {
            try await audioService.start()
            gazeEstimator.start()
            isActive = true
            log("I.R.I.S activated - EyeGestures Python")
        } catch {
            log("Failed to start: \(error)")
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
