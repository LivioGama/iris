import Foundation

public struct IntentResponse: Codable {
    public let target: String
    public let action: String
    public let reasoning: String
    public let confidence: Double
}

public class GeminiService {
    public init() {}

    public func resolveIntent(
        fullScreenBase64: String,
        croppedRegionBase64: String,
        transcript: String,
        gazePoint: CGPoint
    ) async throws -> IntentResponse {
        // Placeholder implementation - returns a mock response
        // In a full implementation, this would call Gemini API for intent resolution
        return IntentResponse(
            target: "Unknown",
            action: "analyze",
            reasoning: "Mock response - GeminiService not fully implemented",
            confidence: 0.5
        )
    }
}
