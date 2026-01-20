import Foundation
import GoogleGenerativeAI
import IRISCore

/// Service responsible for classifying user voice commands into ICOI intents
/// Uses Gemini Flash for fast, accurate intent classification
public class IntentClassificationService {

    private let model: GenerativeModel
    private var apiKey: String?

    public init() {
        // Get API key from UserDefaults (same key as GeminiClient)
        self.apiKey = UserDefaults.standard.string(forKey: "GEMINI_API_KEY")

        // Initialize Gemini 3 Flash Preview model for fast classification
        self.model = GenerativeModel(
            name: "gemini-3-flash-preview",
            apiKey: apiKey ?? "",
            generationConfig: GenerationConfig(
                temperature: 0.1, // Low temperature for consistent classification
                maxOutputTokens: 100 // Need enough tokens for response
            )
        )
    }

    /// Classifies user voice input into an ICOI intent using Gemini Flash
    /// - Parameter input: The user's voice command text
    /// - Returns: IntentClassification with intent and confidence
    public func classifyIntent(input: String) async -> IntentClassification {
        NSLog("🔍🔍🔍 INTENT CLASSIFICATION FUNCTION CALLED")
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

        NSLog("🔍 Intent classification starting for: \"\(normalizedInput)\"")

        // Skip classification for very short inputs
        if normalizedInput.count < 3 {
            print("⚠️ Input too short (\(normalizedInput.count) chars), using general intent")
            return IntentClassification(intent: .general, confidence: 0.0)
        }

        // Check if API key is available
        guard apiKey != nil && !apiKey!.isEmpty else {
            print("⚠️ Gemini API key not set, using general intent")
            return IntentClassification(intent: .general, confidence: 0.0)
        }

        print("✅ API key present, calling Gemini 3.0 Flash for classification...")

        let prompt = """
        Classify this user request into ONE of these intents. Respond with ONLY the intent name, nothing else.

        Intents:
        - messageReply: User wants suggestions for replying to a message
          Examples: "what should I reply", "help me respond", "suggest a reply"

        - codeImprovement: User wants to improve, fix, refactor, optimize, or review code
          Examples: "improve this code", "fix this", "refactor this", "optimize this", "make this better", "review this code", "what's wrong with this"

        - summarize: User wants a summary, key points, or overview of content
          Examples: "summarize this", "what are the key points", "give me an overview"

        - toneFeedback: User wants to analyze or change the tone/style of text
          Examples: "how does this sound", "rewrite this professionally", "make this more polite"

        - chartAnalysis: User wants to understand a graph, chart, or data visualization
          Examples: "explain this chart", "what does this graph show", "analyze this data"

        - general: Anything else that doesn't fit the above (reading, explaining, questions)
          Examples: "what is this", "explain this", "what does this mean"

        User request: "\(normalizedInput)"

        Respond with only one word (the intent name):
        """

        do {
            let response = try await model.generateContent(prompt)

            guard let text = response.text else {
                print("⚠️ No response from Gemini for intent classification")
                return IntentClassification(intent: .general, confidence: 0.0)
            }

            let cleanedResponse = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            print("📥 Gemini responded with: \"\(cleanedResponse)\"")
            print("📥 Raw response (before cleaning): \"\(text)\"")

            // Parse the intent from Gemini's response
            let intent: ICOIIntent

            // Try exact match first
            switch cleanedResponse {
            case "messagereply":
                intent = .messageReply
            case "codeimprovement":
                intent = .codeImprovement
            case "summarize":
                intent = .summarize
            case "tonefeedback":
                intent = .toneFeedback
            case "chartanalysis":
                intent = .chartAnalysis
            case "general":
                intent = .general
            default:
                // Try substring matching as fallback
                print("⚠️ No exact match for '\(cleanedResponse)', trying substring matching...")
                if cleanedResponse.contains("code") || cleanedResponse.contains("improve") {
                    intent = .codeImprovement
                    print("✅ Matched 'codeImprovement' via substring")
                } else if cleanedResponse.contains("message") || cleanedResponse.contains("reply") {
                    intent = .messageReply
                    print("✅ Matched 'messageReply' via substring")
                } else if cleanedResponse.contains("summar") {
                    intent = .summarize
                    print("✅ Matched 'summarize' via substring")
                } else if cleanedResponse.contains("tone") || cleanedResponse.contains("feedback") {
                    intent = .toneFeedback
                    print("✅ Matched 'toneFeedback' via substring")
                } else if cleanedResponse.contains("chart") || cleanedResponse.contains("graph") {
                    intent = .chartAnalysis
                    print("✅ Matched 'chartAnalysis' via substring")
                } else {
                    intent = .general
                    print("⚠️ No match found, defaulting to 'general'")
                }
            }

            // High confidence since Gemini made the decision
            let confidence = intent == .general ? 0.0 : 0.9

            print("🎯 Gemini classified intent: \(intent.rawValue) (confidence: \(confidence))")

            return IntentClassification(
                intent: intent,
                confidence: confidence,
                matchedKeywords: []
            )

        } catch {
            print("❌ Error classifying intent with Gemini: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ Error userInfo: \(nsError.userInfo)")
            }
            return IntentClassification(intent: .general, confidence: 0.0)
        }
    }

    /// Synchronous wrapper that returns general intent (for backward compatibility)
    /// Use the async version for actual classification
    public func classifyIntent(input: String) -> IntentClassification {
        return IntentClassification(intent: .general, confidence: 0.0)
    }
}
