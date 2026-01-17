import Foundation

public struct ChatMessage: Identifiable {
    public let id = UUID()
    public let role: MessageRole
    public let content: String
    public let timestamp: Date

    public init(role: MessageRole, content: String, timestamp: Date) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    public enum MessageRole {
        case user
        case assistant
    }
}
