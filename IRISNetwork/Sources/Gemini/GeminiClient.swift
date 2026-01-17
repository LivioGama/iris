import Foundation

// MARK: - Request/Response Models
public struct GeminiRequest: Codable {
    public struct Content: Codable {
        public struct Part: Codable {
            public let text: String?
            public let inlineData: InlineData?

            public struct InlineData: Codable {
                public let mimeType: String
                public let data: String

                public init(mimeType: String, data: String) {
                    self.mimeType = mimeType
                    self.data = data
                }
            }

            public init(text: String?, inlineData: InlineData?) {
                self.text = text
                self.inlineData = inlineData
            }
        }
        public let role: String
        public let parts: [Part]

        public init(role: String, parts: [Part]) {
            self.role = role
            self.parts = parts
        }
    }
    public let contents: [Content]

    public init(contents: [Content]) {
        self.contents = contents
    }
}

public struct GeminiResponse: Codable {
    public struct Candidate: Codable {
        public struct Content: Codable {
            public struct Part: Codable {
                public let text: String
            }
            public let parts: [Part]
        }
        public let content: Content
    }
    public let candidates: [Candidate]
}

// MARK: - GeminiClient
/// Low-level HTTP communication with Gemini API
/// Responsibility: Network requests only, no business logic
public class GeminiClient {
    private var apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
    private let streamURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:streamGenerateContent"

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
    }

    public func sendRequest(_ request: GeminiRequest) async throws -> GeminiResponse {
        guard !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        return try JSONDecoder().decode(GeminiResponse.self, from: data)
    }

    /// Streams responses from Gemini API, calling onPartialResponse for each chunk
    public func sendStreamingRequest(_ request: GeminiRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let url = URL(string: "\(streamURL)?key=\(apiKey)&alt=sse")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: "Stream request failed")
        }

        var fullText = ""
        var buffer = ""

        // Process streaming response (Server-Sent Events format)
        for try await byte in asyncBytes {
            let char = Character(UnicodeScalar(byte))
            buffer.append(char)

            // SSE messages end with double newline
            if buffer.hasSuffix("\n\n") {
                let lines = buffer.components(separatedBy: "\n")
                for line in lines {
                    if line.hasPrefix("data: ") {
                        let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
                        if let data = jsonString.data(using: .utf8),
                           let response = try? JSONDecoder().decode(GeminiResponse.self, from: data),
                           let text = response.candidates.first?.content.parts.first?.text {
                            fullText += text
                            onPartialResponse(fullText)
                        }
                    }
                }
                buffer = ""
            }
        }

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
