import Foundation
import GoogleGenerativeAI

// MARK: - GeminiClient
/// Low-level communication with Gemini API using official Google SDK
/// Responsibility: Network requests only, no business logic
public class GeminiClient {
    private var apiKey: String
    private var model: GenerativeModel

    public init(apiKey: String) {
        self.apiKey = apiKey
        self.model = GenerativeModel(name: "gemini-3-flash-preview", apiKey: apiKey)
    }

    public func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
        self.model = GenerativeModel(name: "gemini-3-flash-preview", apiKey: newKey)
    }

    /// Sends a request with conversation history and returns complete response
    public func sendRequest(history: [ModelContent]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let chat = model.startChat(history: history.dropLast())
        guard let lastMessage = history.last else {
            throw GeminiError.noResponse
        }

        // Convert ModelContent.Part array to PartsRepresentable
        let response = try await chat.sendMessage(lastMessage.parts.map { $0 })
        return response.text ?? ""
    }

    /// Streams responses from Gemini API, calling onPartialResponse for each chunk
    public func sendStreamingRequest(history: [ModelContent], onPartialResponse: @escaping (String) -> Void) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let chat = model.startChat(history: history.dropLast())
        guard let lastMessage = history.last else {
            throw GeminiError.noResponse
        }

        print("🌐 Starting streaming request...")

        // The parts themselves are PartsRepresentable
        let stream = chat.sendMessageStream(lastMessage.parts.map { $0 })

        var fullText = ""
        for try await chunk in stream {
            if let text = chunk.text {
                fullText += text
                print("📦 Received chunk: \(text.prefix(50))...")
                onPartialResponse(fullText)
            }
        }

        print("✅ Streaming complete, total length: \(fullText.count)")
        return fullText
    }
}

// MARK: - Errors
public enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "GEMINI_API_KEY not set"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .apiError(let statusCode, let message):
            return "Gemini API error \(statusCode): \(message)"
        case .noResponse:
            return "No response from Gemini"
        }
    }
}
