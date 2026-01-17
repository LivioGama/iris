import XCTest
@testable import IRISNetwork
@testable import IRISCore

final class GeminiIntegrationTests: XCTestCase {

    // MARK: - Voice Command to Gemini Response Flow Tests

    func testConversationManagerWithGeminiClient() {
        let conversationManager = ConversationManager(maxHistoryLength: 5)
        let client = GeminiClient(apiKey: "test-key")

        // Simulate a conversation
        let message1 = createUserMessage(text: "Hello")
        conversationManager.addMessage(message1)

        XCTAssertEqual(conversationManager.count, 1)

        let message2 = createModelMessage(text: "Hi there!")
        conversationManager.addMessage(message2)

        XCTAssertEqual(conversationManager.count, 2)

        // Verify client is initialized
        XCTAssertNotNil(client)
    }

    func testConversationHistoryWithGeminiRequest() {
        let conversationManager = ConversationManager(maxHistoryLength: 10)

        // Add several messages
        for i in 1...5 {
            conversationManager.addMessage(createUserMessage(text: "User message \(i)"))
            conversationManager.addMessage(createModelMessage(text: "Model response \(i)"))
        }

        // Build a Gemini request from history
        let history = conversationManager.getHistory()
        let request = GeminiRequest(contents: history)

        XCTAssertEqual(request.contents.count, 10)
        XCTAssertEqual(request.contents[0].role, "user")
        XCTAssertEqual(request.contents[1].role, "model")
    }

    func testConversationPruningWithRequests() {
        let conversationManager = ConversationManager(maxHistoryLength: 5)

        // Add more messages than the limit
        for i in 1...10 {
            conversationManager.addMessage(createUserMessage(text: "Message \(i)"))
        }

        // History should be pruned
        XCTAssertEqual(conversationManager.count, 5)

        // Build request with pruned history
        let history = conversationManager.getHistory()
        let request = GeminiRequest(contents: history)

        XCTAssertEqual(request.contents.count, 5)
        // First message should be preserved
        XCTAssertEqual(request.contents[0].parts[0].text, "Message 1")
        // Last messages should be recent
        XCTAssertEqual(request.contents[4].parts[0].text, "Message 10")
    }

    // MARK: - Blink Detection Workflow Tests

    func testBlinkDetectionMessageFlow() {
        let conversationManager = ConversationManager(maxHistoryLength: 20)

        // Simulate blink detection workflow:
        // 1. User blinks
        // 2. Screenshot is taken
        // 3. Screenshot is sent to Gemini with context
        // 4. Gemini analyzes the screenshot

        // Add initial context message
        let contextMessage = createUserMessageWithImage(
            text: "I blinked. What am I looking at?",
            imageData: "screenshot-base64-data"
        )
        conversationManager.addMessage(contextMessage)

        XCTAssertEqual(conversationManager.count, 1)

        // Verify the message has both text and image data
        let history = conversationManager.getHistory()
        XCTAssertEqual(history[0].parts.count, 2)
        XCTAssertNotNil(history[0].parts[0].text)
        XCTAssertNotNil(history[0].parts[1].inlineData)
    }

    func testMultipleBlinkDetectionCycle() {
        let conversationManager = ConversationManager(maxHistoryLength: 10)

        // Simulate multiple blink-screenshot-analysis cycles
        for i in 1...3 {
            // User blinks and screenshot is analyzed
            let userMessage = createUserMessageWithImage(
                text: "What's on screen? (Blink \(i))",
                imageData: "screenshot-\(i)-data"
            )
            conversationManager.addMessage(userMessage)

            // Gemini responds
            let modelResponse = createModelMessage(text: "Analysis for blink \(i)")
            conversationManager.addMessage(modelResponse)
        }

        XCTAssertEqual(conversationManager.count, 6)

        // Verify conversation flow
        let history = conversationManager.getHistory()
        XCTAssertEqual(history[0].role, "user")
        XCTAssertEqual(history[1].role, "model")
    }

    // MARK: - Error Handling Integration Tests

    func testGeminiClientErrorHandlingWithConversation() async {
        let conversationManager = ConversationManager()
        let client = GeminiClient(apiKey: "")  // Invalid API key

        conversationManager.addMessage(createUserMessage(text: "Hello"))

        let history = conversationManager.getHistory()
        let request = GeminiRequest(contents: history)

        do {
            _ = try await client.sendRequest(request)
            XCTFail("Should have thrown error")
        } catch let error as GeminiError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Wrong error type")
        }
    }

    // MARK: - Long Conversation Tests

    func testLongConversationWithPruning() {
        let conversationManager = ConversationManager(maxHistoryLength: 20)

        // Simulate a long conversation (40 messages)
        for i in 1...20 {
            conversationManager.addMessage(createUserMessage(text: "User \(i)"))
            conversationManager.addMessage(createModelMessage(text: "Model \(i)"))
        }

        // Should be pruned to 20 messages
        XCTAssertEqual(conversationManager.count, 20)

        // Build request
        let history = conversationManager.getHistory()
        let request = GeminiRequest(contents: history)

        XCTAssertEqual(request.contents.count, 20)

        // First message should be preserved
        XCTAssertEqual(request.contents[0].parts[0].text, "User 1")
    }

    // MARK: - Complex Message Flow Tests

    func testMixedMessageTypes() {
        let conversationManager = ConversationManager(maxHistoryLength: 10)

        // Add different types of messages
        conversationManager.addMessage(createUserMessage(text: "Text only"))
        conversationManager.addMessage(createUserMessageWithImage(text: "With image", imageData: "img1"))
        conversationManager.addMessage(createModelMessage(text: "Response 1"))
        conversationManager.addMessage(createUserMessage(text: "Another text"))
        conversationManager.addMessage(createModelMessage(text: "Response 2"))

        XCTAssertEqual(conversationManager.count, 5)

        // Verify message structure
        let history = conversationManager.getHistory()
        XCTAssertEqual(history[0].parts.count, 1)  // Text only
        XCTAssertEqual(history[1].parts.count, 2)  // Text + image
        XCTAssertEqual(history[2].parts.count, 1)  // Response
    }

    // MARK: - Request/Response Serialization Tests

    func testFullRequestResponseCycle() throws {
        let conversationManager = ConversationManager()

        // Add user message
        conversationManager.addMessage(createUserMessage(text: "Hello, Gemini!"))

        // Build request
        let history = conversationManager.getHistory()
        let request = GeminiRequest(contents: history)

        // Encode request
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        XCTAssertFalse(requestData.isEmpty)

        // Simulate response
        let responseJSON = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {
                                "text": "Hello! How can I help you today?"
                            }
                        ]
                    }
                }
            ]
        }
        """

        let responseData = responseJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(GeminiResponse.self, from: responseData)

        // Extract response text
        let responseText = response.candidates[0].content.parts[0].text

        // Add model response to conversation
        conversationManager.addMessage(createModelMessage(text: responseText))

        XCTAssertEqual(conversationManager.count, 2)
        XCTAssertEqual(conversationManager.getHistory()[1].parts[0].text, "Hello! How can I help you today?")
    }

    // MARK: - Concurrent Conversation Management Tests

    func testConcurrentMessageAddition() {
        let conversationManager = ConversationManager(maxHistoryLength: 100)
        let expectation = self.expectation(description: "Concurrent messages")
        expectation.expectedFulfillmentCount = 50

        for i in 0..<50 {
            DispatchQueue.global().async {
                conversationManager.addMessage(self.createUserMessage(text: "Message \(i)"))
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should have received 50 messages
        XCTAssertEqual(conversationManager.count, 50)
    }

    // MARK: - Memory Management Tests

    func testConversationManagerMemoryCleanup() {
        weak var weakManager: ConversationManager?

        autoreleasepool {
            let manager = ConversationManager()
            weakManager = manager

            for i in 1...10 {
                manager.addMessage(createUserMessage(text: "Message \(i)"))
            }
        }

        // Manager should be deallocated
        XCTAssertNil(weakManager)
    }

    // MARK: - Clear History Integration Tests

    func testClearHistoryAndRebuild() {
        let conversationManager = ConversationManager()

        // Add messages
        for i in 1...5 {
            conversationManager.addMessage(createUserMessage(text: "Message \(i)"))
        }

        XCTAssertEqual(conversationManager.count, 5)

        // Clear history
        conversationManager.clearHistory()
        XCTAssertEqual(conversationManager.count, 0)

        // Start new conversation
        conversationManager.addMessage(createUserMessage(text: "New conversation"))
        XCTAssertEqual(conversationManager.count, 1)
    }

    // MARK: - Helper Methods

    private func createUserMessage(text: String) -> GeminiRequest.Content {
        return GeminiRequest.Content(
            role: "user",
            parts: [GeminiRequest.Content.Part(text: text, inlineData: nil)]
        )
    }

    private func createModelMessage(text: String) -> GeminiRequest.Content {
        return GeminiRequest.Content(
            role: "model",
            parts: [GeminiRequest.Content.Part(text: text, inlineData: nil)]
        )
    }

    private func createUserMessageWithImage(text: String, imageData: String) -> GeminiRequest.Content {
        let inlineData = GeminiRequest.Content.Part.InlineData(
            mimeType: "image/png",
            data: imageData
        )

        return GeminiRequest.Content(
            role: "user",
            parts: [
                GeminiRequest.Content.Part(text: text, inlineData: nil),
                GeminiRequest.Content.Part(text: nil, inlineData: inlineData)
            ]
        )
    }
}

// MARK: - GeminiError Equatable Extension
extension GeminiError: Equatable {
    public static func == (lhs: GeminiError, rhs: GeminiError) -> Bool {
        switch (lhs, rhs) {
        case (.missingAPIKey, .missingAPIKey),
             (.invalidResponse, .invalidResponse),
             (.noResponse, .noResponse):
            return true
        case (.apiError(let lhsCode, let lhsMessage), .apiError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
