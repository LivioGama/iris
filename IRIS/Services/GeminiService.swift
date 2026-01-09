import Foundation

@MainActor
class GeminiService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    
    init() {
        self.apiKey = KeychainService.getAPIKey() ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    }
    
    func resolveIntent(
        fullScreenBase64: String,
        croppedRegionBase64: String,
        transcript: String,
        gazePoint: CGPoint
    ) async throws -> IntentResponse {
        let prompt = PromptBuilder.buildIntentResolutionPrompt(
            transcript: transcript,
            gazePoint: gazePoint
        )
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/png",
                                "data": fullScreenBase64
                            ]
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/png",
                                "data": croppedRegionBase64
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "topP": 0.8,
                "maxOutputTokens": 1024
            ]
        ]
        
        var request = URLRequest(url: URL(string: "\(baseURL)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.apiError
        }
        
        return try parseResponse(data)
    }
    
    private func parseResponse(_ data: Data) throws -> IntentResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiError.parsingFailed
        }
        
        return parseIntentFromText(text)
    }
    
    private func parseIntentFromText(_ text: String) -> IntentResponse {
        var target = "Unknown element"
        var action = "Unknown action"
        var reasoning = text
        var confidence = 0.5
        
        if let targetMatch = text.range(of: "TARGET: (.+)", options: .regularExpression) {
            target = String(text[targetMatch]).replacingOccurrences(of: "TARGET: ", with: "")
                .components(separatedBy: "\n").first ?? target
        }
        
        if let actionMatch = text.range(of: "ACTION: (.+)", options: .regularExpression) {
            action = String(text[actionMatch]).replacingOccurrences(of: "ACTION: ", with: "")
                .components(separatedBy: "\n").first ?? action
        }
        
        if let confidenceMatch = text.range(of: "CONFIDENCE: ([0-9.]+)", options: .regularExpression) {
            let confStr = String(text[confidenceMatch]).replacingOccurrences(of: "CONFIDENCE: ", with: "")
            confidence = Double(confStr) ?? 0.5
        }
        
        if let reasoningMatch = text.range(of: "REASONING: (.+)", options: .regularExpression) {
            reasoning = String(text[reasoningMatch]).replacingOccurrences(of: "REASONING: ", with: "")
        }
        
        return IntentResponse(
            target: target.trimmingCharacters(in: .whitespacesAndNewlines),
            action: action.trimmingCharacters(in: .whitespacesAndNewlines),
            reasoning: reasoning.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: confidence
        )
    }
}

struct IntentResponse {
    let target: String
    let action: String
    let reasoning: String
    let confidence: Double
}

enum GeminiError: Error {
    case apiError
    case parsingFailed
    case missingAPIKey
}

class KeychainService {
    static func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.iris.gemini-api",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    static func setAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.iris.gemini-api",
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
