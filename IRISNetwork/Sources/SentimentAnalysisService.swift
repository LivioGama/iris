import Foundation
import NaturalLanguage
import IRISCore

public struct SentimentAnalysisResponse: Codable {
    let analysis: String
}

// Gemini API structures
public struct GeminiAnalysisRequest: Codable {
    struct Content: Codable {
        struct Part: Codable {
            let text: String
        }
        let parts: [Part]
    }
    let contents: [Content]
}

public struct GeminiAnalysisResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

public class SentimentAnalysisService {
    static let shared = SentimentAnalysisService()

    private let apiKey: String

    // System and analysis prompts from the judge endpoint
    private let systemPrompt = "Tu es un expert en analyse comportementale. Tu donnes des réponses concises et percutantes, en 3-4 phrases maximum."

    private let analysisPrompt = """
    Analyse brièvement le texte suivant: décris l'attitude, la posture émotionnelle et l'image renvoyée par l'auteur. Mets en évidence les traits de caractère et la dynamique relationnelle. Réponds de manière fluide et nuancée en 3-4 phrases.

    Réponds dans la langue du texte.

    Texte:
    """

    public init() {
        // Try to get API key from Keychain first, fallback to environment variable for backwards compatibility
        if let keychainKey = try? KeychainService.shared.getAPIKey() {
            self.apiKey = keychainKey
        } else {
            self.apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        }
    }

    public func analyzeSentiment(_ text: String) async throws -> SentimentAnalysisResponse {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "SentimentAnalysis", code: -1, userInfo: [NSLocalizedDescriptionKey: "GEMINI_API_KEY not set"])
        }

        // Combine system prompt, analysis prompt, and user text
        let fullPrompt = systemPrompt + "\n\n" + analysisPrompt + "\n" + text

        // Create Gemini request
        let request = GeminiAnalysisRequest(
            contents: [
                GeminiAnalysisRequest.Content(
                    parts: [
                        GeminiAnalysisRequest.Content.Part(text: fullPrompt)
                    ]
                )
            ]
        )

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SentimentAnalysis", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SentimentAnalysis", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API error: \(errorText)"])
        }

        let geminiResponse = try JSONDecoder().decode(GeminiAnalysisResponse.self, from: data)

        guard let analysis = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw NSError(domain: "SentimentAnalysis", code: -1, userInfo: [NSLocalizedDescriptionKey: "No analysis in response"])
        }

        return SentimentAnalysisResponse(analysis: analysis)
    }

    public func detectsSentimentRequest(in prompt: String) -> Bool {
        let lowercased = prompt.lowercased()
        let sentimentKeywords = [
            "judge",
            "analyze",
            "sentiment",
            "personality",
            "who said",
            "who wrote",
            "messages",
            "extract messages",
            "list messages"
        ]

        return sentimentKeywords.contains { keyword in
            lowercased.contains(keyword)
        }
    }

    public func detectsMessageNumber(in prompt: String) -> Int? {
        // NER-style extraction using Apple's NaturalLanguage framework
        let lowercased = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔢 NER: Detecting number from: '\(prompt)'")

        // Use NLTagger to tokenize and tag the text
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = prompt

        var detectedNumbers: [Int] = []

        // Strategy 1: Use NLTagger to find numbers in the text
        tagger.enumerateTags(in: prompt.startIndex..<prompt.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let token = String(prompt[tokenRange])

            // Check if it's tagged as a number or if it contains digits
            if tag == .number || token.rangeOfCharacter(from: .decimalDigits) != nil {
                if let number = Int(token) {
                    print("🔢 NLTagger found number token: '\(token)' -> \(number)")
                    detectedNumbers.append(number)
                }
            }

            return true
        }

        // If NLTagger found numbers, return the first one
        if let firstNumber = detectedNumbers.first {
            print("✅ NER extracted: \(firstNumber)")
            return firstNumber
        }

        // Strategy 2: Word-to-number mapping (including ordinals)
        let wordToNumber: [String: Int] = [
            "one": 1, "first": 1, "1st": 1,
            "two": 2, "second": 2, "2nd": 2,
            "three": 3, "third": 3, "3rd": 3,
            "four": 4, "fourth": 4, "4th": 4,
            "five": 5, "fifth": 5, "5th": 5,
            "six": 6, "sixth": 6, "6th": 6,
            "seven": 7, "seventh": 7, "7th": 7,
            "eight": 8, "eighth": 8, "8th": 8,
            "nine": 9, "ninth": 9, "9th": 9,
            "ten": 10, "tenth": 10, "10th": 10,
            "eleven": 11, "eleventh": 11, "11th": 11,
            "twelve": 12, "twelfth": 12, "12th": 12,
            "thirteen": 13, "thirteenth": 13, "13th": 13,
            "fourteen": 14, "fourteenth": 14, "14th": 14,
            "fifteen": 15, "fifteenth": 15, "15th": 15,
            "sixteen": 16, "sixteenth": 16, "16th": 16,
            "seventeen": 17, "seventeenth": 17, "17th": 17,
            "eighteen": 18, "eighteenth": 18, "18th": 18,
            "nineteen": 19, "nineteenth": 19, "19th": 19,
            "twenty": 20, "twentieth": 20, "20th": 20
        ]

        // Strategy 3: Look for word numbers in the text
        let tokens = lowercased.components(separatedBy: .whitespaces)
        for token in tokens {
            let cleanToken = token.trimmingCharacters(in: .punctuationCharacters)
            if let number = wordToNumber[cleanToken] {
                print("✅ Word mapping found: '\(cleanToken)' -> \(number)")
                return number
            }
        }

        // Strategy 4: Direct number (e.g., "4", "10")
        if let number = Int(lowercased) {
            print("✅ Direct number: \(number)")
            return number
        }

        // Strategy 5: Regex fallback for digits anywhere in text
        let digitPattern = #"\d+"#
        if let regex = try? NSRegularExpression(pattern: digitPattern),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
           let range = Range(match.range, in: lowercased),
           let number = Int(lowercased[range]) {
            print("✅ Regex found digit: \(number)")
            return number
        }

        print("❌ No number detected in '\(prompt)'")
        return nil
    }
}
