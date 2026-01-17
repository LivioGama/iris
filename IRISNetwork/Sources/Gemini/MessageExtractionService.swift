import Foundation

/// Extracts and parses numbered messages from text
/// Responsibility: Message parsing and extraction logic
public class MessageExtractionService {
    public init() {}

    /// Extracts numbered messages from Gemini's vision response
    /// Expected format: "1. message text\n2. another message\n3. third message"
    /// - Parameter text: Response text containing numbered messages
    /// - Returns: Array of extracted message strings
    public func extractMessages(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var messages: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match lines starting with number followed by . or ) or :
            if let range = trimmed.range(of: "^\\d+[.):]\\s*", options: .regularExpression) {
                let messageText = trimmed[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !messageText.isEmpty {
                    messages.append(String(messageText))
                }
            }
        }

        print("📋 MessageExtractionService: Extracted \(messages.count) messages")
        return messages
    }

    /// Validates a message number against available messages
    /// - Parameters:
    ///   - number: The message number (1-indexed)
    ///   - totalMessages: Total number of available messages
    /// - Returns: True if the number is valid
    public func isValidMessageNumber(_ number: Int, totalMessages: Int) -> Bool {
        return number > 0 && number <= totalMessages
    }

    /// Formats extracted messages as a numbered list
    /// - Parameter messages: Array of message strings
    /// - Returns: Formatted string with numbered messages
    public func formatMessageList(_ messages: [String]) -> String {
        return messages.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
    }
}
