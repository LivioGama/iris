import Foundation

struct IntentResponse: Codable {
    let target: String
    let action: String
    let reasoning: String
    let confidence: Double
}

class GeminiService {
    func resolveIntent(
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
