import Foundation
import IRISCore
import IRISNetwork

// MARK: - Intent Response Model
struct IntentResponse: Codable {
    let target: String
    let action: String
    let reasoning: String
    let confidence: Double
}

// MARK: - Intent Resolver
/// Resolves user intent from gaze + voice input
/// TODO: Integrate with GeminiClient for real intent resolution via Gemini API
/// Currently returns mock responses for architectural completeness
@MainActor
class IntentResolver: ObservableObject {
    @Published var lastResult: ResolvedIntent?
    @Published var isResolving = false

    private let confidenceThreshold = 0.4

    var onResolved: ((ResolvedIntent) -> Void)?
    var onLowConfidence: ((ResolvedIntent) -> Void)?

    func resolve(
        fullScreenImage: String,
        croppedImage: String,
        transcript: String,
        gazePoint: CGPoint
    ) async throws -> ResolvedIntent {
        isResolving = true
        defer { isResolving = false }

        // TODO: Replace with real Gemini API call using GeminiClient
        // This placeholder implementation allows the architecture to function
        // while real intent resolution is pending implementation
        let response = IntentResponse(
            target: "Unknown",
            action: "analyze",
            reasoning: "Mock response - Intent resolution not fully implemented",
            confidence: 0.5
        )

        let intent = ResolvedIntent(
            target: response.target,
            action: response.action,
            reasoning: response.reasoning,
            confidence: response.confidence
        )

        lastResult = intent

        if intent.confidence >= confidenceThreshold {
            onResolved?(intent)
        } else {
            onLowConfidence?(intent)
        }

        return intent
    }

    func clearResult() {
        lastResult = nil
    }
}
