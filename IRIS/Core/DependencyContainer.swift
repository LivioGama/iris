import Foundation
import IRISCore
import IRISGaze
import IRISVision
import IRISNetwork
import IRISMedia

/// Dependency injection container for IRIS services
/// Provides centralized service management with clear dependencies
@MainActor
class DependencyContainer {
    // MARK: - Singleton

    static let shared = DependencyContainer()

    // MARK: - Service Instances

    // Media Services
    private(set) lazy var cameraService: CameraService = {
        CameraService()
    }()

    private(set) lazy var audioService: IRISMedia.AudioService = {
        IRISMedia.AudioService()
    }()

    private(set) lazy var speechService: SpeechService = {
        SpeechService()
    }()

    private(set) lazy var screenCaptureService: IRISMedia.ScreenCaptureService = {
        IRISMedia.ScreenCaptureService()
    }()

    private(set) lazy var screenshotService: ScreenshotService = {
        ScreenshotService()
    }()

    private(set) lazy var voiceInteractionService: VoiceInteractionService = {
        VoiceInteractionService()
    }()

    // Vision Services
    private(set) lazy var accessibilityDetector: AccessibilityDetector = {
        AccessibilityDetector()
    }()

    private(set) lazy var computerVisionDetector: ComputerVisionDetector = {
        ComputerVisionDetector()
    }()

    private(set) lazy var visionTextDetector: VisionTextDetector = {
        VisionTextDetector()
    }()

    private(set) lazy var contextualAnalysisService: ContextualAnalysisService = {
        ContextualAnalysisService()
    }()

    // Gaze Services
    private(set) lazy var gazeEstimator: GazeEstimator = {
        GazeEstimator()
    }()

    // Network Services
    private(set) lazy var geminiClient: GeminiClient = {
        // Try to get API key from environment variable first
        var apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""

        // If not found, try to load from .zshrc
        if apiKey.isEmpty {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let zshrcPath = "\(homeDir)/.zshrc"

            if let zshrcContent = try? String(contentsOfFile: zshrcPath, encoding: .utf8) {
                // Parse GEMINI_API_KEY from .zshrc
                let lines = zshrcContent.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    // Match: export GEMINI_API_KEY="..." or export GEMINI_API_KEY='...'
                    if trimmed.hasPrefix("export GEMINI_API_KEY=") {
                        let keyValue = trimmed.replacingOccurrences(of: "export GEMINI_API_KEY=", with: "")
                        // Remove quotes
                        apiKey = keyValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        print("🔑 Loaded GEMINI_API_KEY from .zshrc")
                        break
                    }
                }
            }
        }

        if apiKey.isEmpty {
            print("⚠️ GEMINI_API_KEY not found in environment or .zshrc")
        }

        return GeminiClient(apiKey: apiKey)
    }()

    private(set) lazy var conversationManager: ConversationManager = {
        ConversationManager(maxHistoryLength: 20)
    }()

    private(set) lazy var messageExtractionService: MessageExtractionService = {
        MessageExtractionService()
    }()

    private(set) lazy var sentimentAnalysisService: SentimentAnalysisService = {
        SentimentAnalysisService.shared
    }()

    private(set) lazy var geminiAssistant: GeminiAssistantOrchestrator = {
        GeminiAssistantOrchestrator(
            geminiClient: geminiClient,
            conversationManager: conversationManager,
            voiceInteractionService: voiceInteractionService,
            messageExtractionService: messageExtractionService,
            screenshotService: screenshotService
        )
    }()

    // Core Services
    private(set) lazy var intentTrigger: IntentTrigger = {
        IntentTrigger()
    }()

    private(set) lazy var intentResolver: IntentResolver = {
        IntentResolver()
    }()

    // MARK: - Initialization

    private init() {
        // Private initializer to enforce singleton pattern
    }

    // MARK: - Factory Methods

    /// Creates a new IRISCoordinator with all dependencies injected
    func makeCoordinator() -> IRISCoordinator {
        return IRISCoordinator(container: self)
    }

    // MARK: - Service Access

    /// Returns a gaze tracking service conforming to the protocol
    func makeGazeTrackingService() -> any GazeTrackingService {
        return gazeEstimator
    }

    /// Returns an AI assistant service conforming to the protocol
    func makeAIAssistantService() -> any AIAssistantService {
        return geminiAssistant
    }

    /// Returns an element detection service conforming to the protocol
    func makeElementDetectionService() -> any ElementDetectionService {
        return accessibilityDetector
    }

    /// Returns a screen capture service conforming to the protocol
    func makeScreenCaptureService() -> any ScreenCaptureServiceProtocol {
        return screenCaptureService
    }

    /// Returns an audio service
    func makeAudioService() -> any AudioServiceProtocol {
        return audioService
    }

    /// Returns a speech recognition service
    func makeSpeechRecognitionService() -> any SpeechRecognitionService {
        return speechService
    }

    /// Returns an intent resolution service
    func makeIntentResolutionService() -> any IntentResolutionService {
        return intentResolver
    }

    /// Returns a contextual analysis service
    func makeContextualAnalysisService() -> any ContextualAnalysisServiceProtocol {
        return contextualAnalysisService
    }

    // MARK: - Reset

    /// Resets all services (useful for testing or app reset)
    func reset() {
        // Stop all services
        gazeEstimator.stop()
        audioService.stop()

        // Clear any cached state
        conversationManager.clearHistory()
    }

    // MARK: - API Key Management

    /// Reloads the API key from environment variable and updates the Gemini client
    func reloadAPIKey() {
        let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        geminiClient.updateAPIKey(apiKey)
        print("🔑 API Key reloaded from environment variable")
    }

    // MARK: - Testing Support

    #if DEBUG
    /// Allows overriding services for testing
    private var serviceOverrides: [String: Any] = [:]

    func override<T>(_ service: T, forKey key: String) {
        serviceOverrides[key] = service
    }

    func clearOverrides() {
        serviceOverrides.removeAll()
    }
    #endif
}

// MARK: - Protocol Conformance Extensions

// These extensions help existing services conform to the protocols defined in Phase 7

@MainActor
extension GazeEstimator: @preconcurrency GazeTrackingService {
    public var currentGaze: CGPoint {
        return gazePoint
    }
}

extension GeminiAssistantOrchestrator: AIAssistantService {
    // Already conforms - no changes needed
}

extension AccessibilityDetector: ElementDetectionService {
    public func detectElement(at point: CGPoint) async -> DetectedElement? {
        return detectElementFast(at: point)
    }
}

@MainActor
extension IRISMedia.ScreenCaptureService: @preconcurrency ScreenCaptureServiceProtocol {
    // Already conforms - no changes needed
}

@MainActor
extension IRISMedia.AudioService: @preconcurrency AudioServiceProtocol {
    // Already conforms - no changes needed
}

@MainActor
extension SpeechService: @preconcurrency SpeechRecognitionService {
    // Already conforms - no changes needed
}

@MainActor
extension IntentResolver: IntentResolutionService {
    // Already conforms - no changes needed
}

extension ContextualAnalysisService: ContextualAnalysisServiceProtocol {
    // Already conforms - no changes needed
}
