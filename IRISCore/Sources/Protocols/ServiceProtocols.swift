import Foundation
import AppKit
import AVFoundation
import CoreGraphics

// MARK: - Gaze Tracking Protocol

public protocol GazeTrackingService {
    var currentGaze: CGPoint { get }
    var isTracking: Bool { get }
    var isTrackingEnabled: Bool { get set }
    var detectedElement: DetectedElement? { get set }

    func start()
    func stop()
    func restart()

    // Event handlers
    var onHoverDetected: ((CGPoint) -> Void)? { get set }
    var onGazeUpdate: ((CGPoint) -> Void)? { get set }
    var onRealTimeDetection: ((DetectedElement) -> Void)? { get set }
    var onBlinkDetected: ((CGPoint, DetectedElement?) -> Void)? { get set }
}

// MARK: - AI Assistant Protocol

public protocol AIAssistantService {
    var isListening: Bool { get }
    var isProcessing: Bool { get }
    var transcribedText: String { get }
    var geminiResponse: String { get }
    var chatMessages: [ChatMessage] { get }

    func handleBlink(at point: CGPoint, focusedElement: DetectedElement?)
    func stopListening()
    func sendTextOnlyToGemini(prompt: String) async
}

// MARK: - Element Detection Protocol

public protocol ElementDetectionService {
    func detectElement(at point: CGPoint) async -> DetectedElement?
    func detectElementFast(at point: CGPoint) -> DetectedElement?
    func detectWindow(at point: CGPoint) -> DetectedElement?
    func isAccessibilityEnabled() -> Bool
}

// MARK: - Screen Capture Protocol

public protocol ScreenCaptureServiceProtocol {
    var preferredScreen: NSScreen? { get set }

    func captureFullScreen() async throws -> CGImage
    func captureCroppedRegion(around point: CGPoint, radius: CGFloat) async throws -> CGImage
    func captureScreen(at point: CGPoint) async throws -> CGImage
    func imageToBase64(_ image: CGImage) -> String?
}

// MARK: - Audio Service Protocol

public protocol AudioServiceProtocol {
    var onVoiceStart: (() -> Void)? { get set }
    var onVoiceEnd: (() -> Void)? { get set }
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)? { get set }

    func start() async throws
    func stop()
}

// MARK: - Speech Recognition Protocol

public protocol SpeechRecognitionService {
    var transcript: String { get }

    func startRecognition() throws
    func stopRecognition()
    func appendBuffer(_ buffer: AVAudioPCMBuffer)
}

// MARK: - Intent Resolution Protocol

public protocol IntentResolutionService {
    func resolve(
        fullScreenImage: String,
        croppedImage: String,
        transcript: String,
        gazePoint: CGPoint
    ) async throws -> ResolvedIntent
}

// MARK: - Contextual Analysis Protocol

public protocol ContextualAnalysisServiceProtocol {
    func analyzeContext(
        around point: CGPoint,
        screenImage: CGImage
    ) async -> DetectedElement?
}
