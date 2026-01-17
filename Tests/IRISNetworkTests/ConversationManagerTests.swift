import XCTest
@testable import IRISNetwork

final class ConversationManagerTests: XCTestCase {

    var conversationManager: ConversationManager!

    override func setUp() {
        super.setUp()
        conversationManager = ConversationManager(maxHistoryLength: 5)
    }

    override func tearDown() {
        conversationManager = nil
        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func testInitialHistoryIsEmpty() {
        XCTAssertEqual(conversationManager.count, 0)
        XCTAssertTrue(conversationManager.getHistory().isEmpty)
    }

    func testAddSingleMessage() {
        let message = createTestMessage(text: "Hello")
        conversationManager.addMessage(message)

        XCTAssertEqual(conversationManager.count, 1)
        XCTAssertEqual(conversationManager.getHistory().count, 1)
    }

    func testAddMultipleMessages() {
        let messages = [
            createTestMessage(text: "Message 1"),
            createTestMessage(text: "Message 2"),
            createTestMessage(text: "Message 3")
        ]

        for message in messages {
            conversationManager.addMessage(message)
        }

        XCTAssertEqual(conversationManager.count, 3)
        XCTAssertEqual(conversationManager.getHistory().count, 3)
    }

    // MARK: - History Pruning Tests

    func testHistoryPruningKeepsFirstMessage() {
        // Add 6 messages (exceeds max of 5)
        for i in 1...6 {
            conversationManager.addMessage(createTestMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(conversationManager.count, 5)

        let history = conversationManager.getHistory()
        XCTAssertEqual(history.count, 5)

        // First message should be preserved
        let firstMessageText = history[0].parts[0].text
        XCTAssertEqual(firstMessageText, "Message 1")
    }

    func testHistoryPruningKeepsRecentMessages() {
        // Add 7 messages (exceeds max of 5 by 2)
        for i in 1...7 {
            conversationManager.addMessage(createTestMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(conversationManager.count, 5)

        let history = conversationManager.getHistory()

        // Should have: Message 1, Message 4, Message 5, Message 6, Message 7
        XCTAssertEqual(history[0].parts[0].text, "Message 1")
        XCTAssertEqual(history[1].parts[0].text, "Message 4")
        XCTAssertEqual(history[2].parts[0].text, "Message 5")
        XCTAssertEqual(history[3].parts[0].text, "Message 6")
        XCTAssertEqual(history[4].parts[0].text, "Message 7")
    }

    func testHistoryPruningWithExactLimit() {
        // Add exactly maxHistoryLength messages
        for i in 1...5 {
            conversationManager.addMessage(createTestMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(conversationManager.count, 5)

        let history = conversationManager.getHistory()
        XCTAssertEqual(history.count, 5)

        // All messages should be preserved
        for (index, message) in history.enumerated() {
            XCTAssertEqual(message.parts[0].text, "Message \(index + 1)")
        }
    }

    func testHistoryPruningBelowLimit() {
        // Add fewer than maxHistoryLength messages
        for i in 1...3 {
            conversationManager.addMessage(createTestMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(conversationManager.count, 3)

        let history = conversationManager.getHistory()
        XCTAssertEqual(history.count, 3)
    }

    func testHistoryPruningWithLargeExcess() {
        // Add many more messages than the limit
        for i in 1...20 {
            conversationManager.addMessage(createTestMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(conversationManager.count, 5)

        let history = conversationManager.getHistory()

        // Should have: Message 1, Message 17, Message 18, Message 19, Message 20
        XCTAssertEqual(history[0].parts[0].text, "Message 1")
        XCTAssertEqual(history[1].parts[0].text, "Message 17")
        XCTAssertEqual(history[2].parts[0].text, "Message 18")
        XCTAssertEqual(history[3].parts[0].text, "Message 19")
        XCTAssertEqual(history[4].parts[0].text, "Message 20")
    }

    // MARK: - Clear History Tests

    func testClearHistory() {
        for i in 1...3 {
            conversationManager.addMessage(createTestMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(conversationManager.count, 3)

        conversationManager.clearHistory()

        XCTAssertEqual(conversationManager.count, 0)
        XCTAssertTrue(conversationManager.getHistory().isEmpty)
    }

    func testClearEmptyHistory() {
        conversationManager.clearHistory()

        XCTAssertEqual(conversationManager.count, 0)
        XCTAssertTrue(conversationManager.getHistory().isEmpty)
    }

    // MARK: - Custom Max Length Tests

    func testCustomMaxHistoryLength() {
        let customManager = ConversationManager(maxHistoryLength: 10)

        for i in 1...15 {
            customManager.addMessage(createTestMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(customManager.count, 10)

        let history = customManager.getHistory()
        XCTAssertEqual(history[0].parts[0].text, "Message 1")
        XCTAssertEqual(history[1].parts[0].text, "Message 7")
    }

    func testMinimumMaxHistoryLength() {
        let minManager = ConversationManager(maxHistoryLength: 2)

        for i in 1...5 {
            minManager.addMessage(createTestMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(minManager.count, 2)

        let history = minManager.getHistory()
        XCTAssertEqual(history[0].parts[0].text, "Message 1")
        XCTAssertEqual(history[1].parts[0].text, "Message 5")
    }

    // MARK: - Edge Cases

    func testSingleMessageNeverPruned() {
        conversationManager.addMessage(createTestMessage(text: "Only Message"))

        XCTAssertEqual(conversationManager.count, 1)

        let history = conversationManager.getHistory()
        XCTAssertEqual(history[0].parts[0].text, "Only Message")
    }

    func testMessagesWithMultipleParts() {
        let multiPartMessage = GeminiRequest.Content(
            role: "user",
            parts: [
                GeminiRequest.Content.Part(text: "Part 1", inlineData: nil),
                GeminiRequest.Content.Part(text: "Part 2", inlineData: nil)
            ]
        )

        conversationManager.addMessage(multiPartMessage)

        XCTAssertEqual(conversationManager.count, 1)

        let history = conversationManager.getHistory()
        XCTAssertEqual(history[0].parts.count, 2)
        XCTAssertEqual(history[0].parts[0].text, "Part 1")
        XCTAssertEqual(history[0].parts[1].text, "Part 2")
    }

    // MARK: - Helper Methods

    private func createTestMessage(text: String, role: String = "user") -> GeminiRequest.Content {
        return GeminiRequest.Content(
            role: role,
            parts: [GeminiRequest.Content.Part(text: text, inlineData: nil)]
        )
    }
}
