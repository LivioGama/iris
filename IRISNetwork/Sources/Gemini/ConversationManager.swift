import Foundation

/// Manages conversation history with automatic pruning to prevent memory leaks
/// Responsibility: Conversation state management with bounded history
public class ConversationManager {
    private let maxHistoryLength: Int
    private var history: [GeminiRequest.Content] = []

    public init(maxHistoryLength: Int = 20) {
        self.maxHistoryLength = maxHistoryLength
    }

    /// Adds a message to conversation history with automatic pruning
    /// Always keeps the first message (initial context) and prunes middle messages when limit is exceeded
    public func addMessage(_ content: GeminiRequest.Content) {
        history.append(content)

        // Prune history if it exceeds max length
        // Keep first message (initial context with screenshot) + last N-1 messages
        if history.count > maxHistoryLength {
            let firstMessage = history.first!
            let recentMessages = Array(history.suffix(maxHistoryLength - 1))
            history = [firstMessage] + recentMessages
            print("📝 ConversationManager: Pruned history to \(history.count) messages (max: \(maxHistoryLength))")
        }
    }

    /// Returns all conversation history
    public func getHistory() -> [GeminiRequest.Content] {
        return history
    }

    /// Clears all conversation history
    public func clearHistory() {
        history.removeAll()
        print("🗑️ ConversationManager: History cleared")
    }

    /// Returns the number of messages in history
    public var count: Int {
        return history.count
    }
}
