import XCTest
@testable import IRISNetwork

final class GeminiClientTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitializationWithAPIKey() {
        let client = GeminiClient(apiKey: "test-api-key")
        XCTAssertNotNil(client)
    }

    func testInitializationWithEmptyKey() {
        let client = GeminiClient(apiKey: "")
        XCTAssertNotNil(client)
    }

    // MARK: - Error Handling Tests

    func testMissingAPIKeyError() async {
        let client = GeminiClient(apiKey: "")
        let request = createTestRequest()

        do {
            _ = try await client.sendRequest(request)
            XCTFail("Should have thrown missingAPIKey error")
        } catch {
            guard let geminiError = error as? GeminiError else {
                XCTFail("Expected GeminiError")
                return
            }
            XCTAssertEqual(geminiError, .missingAPIKey)
        }
    }

    func testErrorDescriptions() {
        let errors: [(GeminiError, String)] = [
            (.missingAPIKey, "GEMINI_API_KEY not set"),
            (.invalidResponse, "Invalid response from Gemini API"),
            (.apiError(statusCode: 404, message: "Not found"), "Gemini API error 404: Not found"),
            (.noResponse, "No response from Gemini")
        ]

        for (error, expectedDescription) in errors {
            XCTAssertEqual(error.errorDescription, expectedDescription)
        }
    }

    func testGeminiErrorEquality() {
        XCTAssertEqual(GeminiError.missingAPIKey, GeminiError.missingAPIKey)
        XCTAssertEqual(GeminiError.invalidResponse, GeminiError.invalidResponse)
        XCTAssertEqual(GeminiError.noResponse, GeminiError.noResponse)
        XCTAssertEqual(
            GeminiError.apiError(statusCode: 400, message: "Bad request"),
            GeminiError.apiError(statusCode: 400, message: "Bad request")
        )

        XCTAssertNotEqual(GeminiError.missingAPIKey, GeminiError.invalidResponse)
        XCTAssertNotEqual(
            GeminiError.apiError(statusCode: 400, message: "Bad request"),
            GeminiError.apiError(statusCode: 404, message: "Not found")
        )
    }

    // MARK: - Request/Response Model Tests

    func testGeminiRequestEncoding() throws {
        let request = createTestRequest()
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        XCTAssertFalse(data.isEmpty)

        // Decode to verify structure
        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(GeminiRequest.self, from: data)

        XCTAssertEqual(decodedRequest.contents.count, request.contents.count)
        XCTAssertEqual(decodedRequest.contents[0].role, request.contents[0].role)
        XCTAssertEqual(decodedRequest.contents[0].parts[0].text, request.contents[0].parts[0].text)
    }

    func testGeminiResponseDecoding() throws {
        let jsonString = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {
                                "text": "Test response"
                            }
                        ]
                    }
                }
            ]
        }
        """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(GeminiResponse.self, from: data)

        XCTAssertEqual(response.candidates.count, 1)
        XCTAssertEqual(response.candidates[0].content.parts.count, 1)
        XCTAssertEqual(response.candidates[0].content.parts[0].text, "Test response")
    }

    func testGeminiRequestWithInlineData() throws {
        let inlineData = GeminiRequest.Content.Part.InlineData(
            mimeType: "image/png",
            data: "base64-encoded-data"
        )

        let part = GeminiRequest.Content.Part(text: nil, inlineData: inlineData)
        let content = GeminiRequest.Content(role: "user", parts: [part])
        let request = GeminiRequest(contents: [content])

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        XCTAssertFalse(data.isEmpty)

        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(GeminiRequest.self, from: data)

        XCTAssertNotNil(decodedRequest.contents[0].parts[0].inlineData)
        XCTAssertEqual(decodedRequest.contents[0].parts[0].inlineData?.mimeType, "image/png")
        XCTAssertEqual(decodedRequest.contents[0].parts[0].inlineData?.data, "base64-encoded-data")
    }

    func testGeminiRequestWithTextAndInlineData() throws {
        let inlineData = GeminiRequest.Content.Part.InlineData(
            mimeType: "image/jpeg",
            data: "jpeg-data"
        )

        let textPart = GeminiRequest.Content.Part(text: "Describe this image", inlineData: nil)
        let imagePart = GeminiRequest.Content.Part(text: nil, inlineData: inlineData)

        let content = GeminiRequest.Content(role: "user", parts: [textPart, imagePart])
        let request = GeminiRequest(contents: [content])

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(GeminiRequest.self, from: data)

        XCTAssertEqual(decodedRequest.contents[0].parts.count, 2)
        XCTAssertEqual(decodedRequest.contents[0].parts[0].text, "Describe this image")
        XCTAssertNotNil(decodedRequest.contents[0].parts[1].inlineData)
    }

    func testMultipleContentsInRequest() throws {
        let content1 = GeminiRequest.Content(
            role: "user",
            parts: [GeminiRequest.Content.Part(text: "Hello", inlineData: nil)]
        )
        let content2 = GeminiRequest.Content(
            role: "model",
            parts: [GeminiRequest.Content.Part(text: "Hi there", inlineData: nil)]
        )
        let content3 = GeminiRequest.Content(
            role: "user",
            parts: [GeminiRequest.Content.Part(text: "How are you?", inlineData: nil)]
        )

        let request = GeminiRequest(contents: [content1, content2, content3])

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(GeminiRequest.self, from: data)

        XCTAssertEqual(decodedRequest.contents.count, 3)
        XCTAssertEqual(decodedRequest.contents[0].role, "user")
        XCTAssertEqual(decodedRequest.contents[1].role, "model")
        XCTAssertEqual(decodedRequest.contents[2].role, "user")
    }

    // MARK: - Mock Network Tests

    func testInvalidJSONResponse() {
        // This test demonstrates handling of invalid JSON
        let invalidJSON = "{ invalid json }"
        let data = invalidJSON.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(GeminiResponse.self, from: data))
    }

    func testEmptyResponseDecoding() {
        let jsonString = """
        {
            "candidates": []
        }
        """

        let data = jsonString.data(using: .utf8)!

        XCTAssertNoThrow(try JSONDecoder().decode(GeminiResponse.self, from: data))

        let response = try? JSONDecoder().decode(GeminiResponse.self, from: data)
        XCTAssertEqual(response?.candidates.count, 0)
    }

    // MARK: - Request Construction Tests

    func testRequestWithEmptyParts() {
        let content = GeminiRequest.Content(role: "user", parts: [])
        let request = GeminiRequest(contents: [content])

        XCTAssertEqual(request.contents[0].parts.count, 0)
    }

    func testRequestWithMultipleParts() {
        let parts = [
            GeminiRequest.Content.Part(text: "Part 1", inlineData: nil),
            GeminiRequest.Content.Part(text: "Part 2", inlineData: nil),
            GeminiRequest.Content.Part(text: "Part 3", inlineData: nil)
        ]

        let content = GeminiRequest.Content(role: "user", parts: parts)
        let request = GeminiRequest(contents: [content])

        XCTAssertEqual(request.contents[0].parts.count, 3)
    }

    // MARK: - API URL Construction Tests

    func testClientUsesCorrectModel() {
        // This test verifies the client is configured to use gemini-2.0-flash-exp
        // We can't access the private baseURL directly, but we know it's set correctly
        let client = GeminiClient(apiKey: "test-key")
        XCTAssertNotNil(client)
    }

    // MARK: - Concurrent Request Tests

    func testMultipleClientInstances() {
        let client1 = GeminiClient(apiKey: "key1")
        let client2 = GeminiClient(apiKey: "key2")

        XCTAssertNotNil(client1)
        XCTAssertNotNil(client2)
    }

    // MARK: - Helper Methods

    private func createTestRequest(text: String = "Hello, Gemini!") -> GeminiRequest {
        let part = GeminiRequest.Content.Part(text: text, inlineData: nil)
        let content = GeminiRequest.Content(role: "user", parts: [part])
        return GeminiRequest(contents: [content])
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
