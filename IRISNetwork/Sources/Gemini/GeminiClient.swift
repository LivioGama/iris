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
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"

    public init(apiKey: String) {
        self.apiKey = apiKey
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
