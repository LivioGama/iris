import Foundation
import NaturalLanguage

/// Service responsible for classifying user voice commands into ICOI intents
/// Uses keyword matching and natural language processing to determine user intent
public class IntentClassificationService {

    private let tagger = NLTagger(tagSchemes: [.lexicalClass])
    private let minimumConfidence: Double = 0.3

    public init() {}

    /// Classifies user voice input into an ICOI intent
    /// - Parameter input: The user's voice command text
    /// - Returns: IntentClassification with intent, confidence, and matched keywords
    public func classifyIntent(input: String) -> IntentClassification {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Skip classification for very short inputs
        if normalizedInput.count < 3 {
            return IntentClassification(intent: .general, confidence: 0.0)
        }

        var bestIntent: ICOIIntent = .general
        var bestConfidence: Double = 0.0
        var bestKeywords: [String] = []

        // Check each intent for keyword matches
        for intent in ICOIIntent.allCases where intent != .general {
            let (confidence, matchedKeywords) = calculateIntentConfidence(input: normalizedInput, for: intent)

            if confidence > bestConfidence {
                bestIntent = intent
                bestConfidence = confidence
                bestKeywords = matchedKeywords
            }
        }

        // Use general intent if no specific intent has sufficient confidence
        if bestConfidence < minimumConfidence {
            return IntentClassification(intent: .general, confidence: 0.0)
        }

        return IntentClassification(
            intent: bestIntent,
            confidence: bestConfidence,
            matchedKeywords: bestKeywords
        )
    }

    /// Calculates confidence score for a specific intent based on keyword matching
    private func calculateIntentConfidence(input: String, for intent: ICOIIntent) -> (confidence: Double, matchedKeywords: [String]) {
        let keywords = intent.keywords
        var matchedKeywords: [String] = []
        var totalScore = 0.0

        // Check for exact keyword matches
        for keyword in keywords {
            let normalizedKeyword = keyword.lowercased()

            if input.contains(normalizedKeyword) {
                matchedKeywords.append(keyword)

                // Give higher weight to longer, more specific keywords
                let keywordWeight = Double(normalizedKeyword.count) / 20.0 // Normalize by typical keyword length
                totalScore += keywordWeight

                // Bonus for keyword at start of sentence
                if input.hasPrefix(normalizedKeyword) {
                    totalScore += 0.3
                }
            }
        }

        // Check for semantic similarity using word stems
        let inputWords = input.components(separatedBy: .whitespacesAndNewlines)
        let stemmedInput = inputWords.map { stem(word: $0) }

        for keyword in keywords {
            let keywordWords = keyword.components(separatedBy: .whitespacesAndNewlines)
            let stemmedKeyword = keywordWords.map { stem(word: $0) }

            // Check if any keyword stems appear in input
            for stem in stemmedKeyword {
                if stemmedInput.contains(stem) && !matchedKeywords.contains(keyword) {
                    matchedKeywords.append(keyword)
                    totalScore += 0.2 // Lower weight for stem matches
                }
            }
        }

        // Normalize confidence score (0.0 to 1.0)
        let confidence = min(totalScore / 2.0, 1.0) // Max score of 2.0 for perfect matches

        return (confidence, matchedKeywords)
    }

    /// Simple word stemming for better keyword matching
    private func stem(word: String) -> String {
        let lowercaseWord = word.lowercased()

        // Basic English stemming rules
        if lowercaseWord.hasSuffix("ing") && lowercaseWord.count > 4 {
            return String(lowercaseWord.dropLast(3))
        }
        if lowercaseWord.hasSuffix("ed") && lowercaseWord.count > 3 {
            return String(lowercaseWord.dropLast(2))
        }
        if lowercaseWord.hasSuffix("er") && lowercaseWord.count > 3 {
            return String(lowercaseWord.dropLast(2))
        }
        if lowercaseWord.hasSuffix("est") && lowercaseWord.count > 4 {
            return String(lowercaseWord.dropLast(3))
        }
        if lowercaseWord.hasSuffix("s") && lowercaseWord.count > 2 {
            return String(lowercaseWord.dropLast())
        }

        return lowercaseWord
    }

    /// Returns a list of all available intents for debugging/testing
    public func getAllIntents() -> [ICOIIntent] {
        return ICOIIntent.allCases
    }

    /// Tests intent classification with sample inputs
    public func testClassification(testInputs: [String]) -> [String: IntentClassification] {
        var results: [String: IntentClassification] = [:]

        for input in testInputs {
            results[input] = classifyIntent(input: input)
        }

        return results
    }
}