import Foundation
import GoogleGenerativeAI

// MARK: - GeminiClient
/// Low-level communication with Gemini API using official Google SDK
/// Responsibility: Network requests only, no business logic
public class GeminiClient {
    private var apiKey: String
    private var model: GenerativeModel
    public var tools: [Tool]?

    public init(apiKey: String, tools: [Tool]? = nil) {
        self.apiKey = apiKey
        self.tools = tools
        self.model = GenerativeModel(
            name: "gemini-3-flash-preview", 
            apiKey: apiKey,
            tools: tools
        )
    }

    public func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
        self.model = GenerativeModel(
            name: "gemini-3-flash-preview", 
            apiKey: newKey,
            tools: self.tools
        )
    }
    
    public func updateTools(_ newTools: [Tool]?) {
        self.tools = newTools
        self.model = GenerativeModel(
            name: "gemini-3-flash-preview", 
            apiKey: self.apiKey,
            tools: newTools
        )
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
    
    /// Sends a request and returns the full response object (including function calls)
    public func sendRequestForResponse(history: [ModelContent]) async throws -> GenerateContentResponse {
        guard !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let chat = model.startChat(history: history.dropLast())
        guard let lastMessage = history.last else {
            throw GeminiError.noResponse
        }

        return try await chat.sendMessage(lastMessage.parts.map { $0 })
    }

    /// Streams responses from Gemini API, calling onPartialResponse for each chunk
    /// Returns the full text and any function calls
    public func sendStreamingRequest(history: [ModelContent], onPartialResponse: @escaping (String) -> Void) async throws -> (String, [FunctionCall]) {
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
        var allFunctionCalls: [FunctionCall] = []
        
        for try await chunk in stream {
            if let text = chunk.text {
                fullText += text
                print("📦 Received chunk: \(text.prefix(50))...")
                onPartialResponse(fullText)
            }
            // Capture function calls from chunks
            allFunctionCalls.append(contentsOf: chunk.functionCalls)
        }

        print("✅ Streaming complete, total length: \(fullText.count), function calls: \(allFunctionCalls.count)")
        return (fullText, allFunctionCalls)
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
