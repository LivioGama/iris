import Foundation

public struct ResolvedIntent: Identifiable {
    public let id = UUID()
    public let target: String
    public let action: String
    public let reasoning: String
    public let confidence: Double

    public init(target: String, action: String, reasoning: String, confidence: Double) {
        self.target = target
        self.action = action
        self.reasoning = reasoning
        self.confidence = confidence
    }
}
