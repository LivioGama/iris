//
//  IntentClassificationService.swift
//  IRIS
//
//  Simple local intent classification using keyword matching
//

import Foundation
import IRISCore

/// Simple intent classification service using keyword matching
/// For more sophisticated classification, the proactive mode uses Gemini directly
class IntentClassificationService {

    /// Classifies user input into an intent category
    func classifyIntent(input: String) async -> IntentClassification {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Code improvement patterns
        let codePatterns = ["improve", "refactor", "clean up", "optimize", "make better", "fix code", "code review"]
        for pattern in codePatterns {
            if normalized.contains(pattern) {
                return IntentClassification(intent: .codeImprovement, confidence: 0.8, matchedKeywords: [pattern])
            }
        }

        // Bug fix patterns
        let bugPatterns = ["fix", "bug", "error", "broken", "wrong", "issue", "problem", "debug"]
        for pattern in bugPatterns {
            if normalized.contains(pattern) {
                return IntentClassification(intent: .codeImprovement, confidence: 0.75, matchedKeywords: [pattern])
            }
        }

        // Summarize patterns
        let summarizePatterns = ["summarize", "summary", "tldr", "key points", "main points", "overview"]
        for pattern in summarizePatterns {
            if normalized.contains(pattern) {
                return IntentClassification(intent: .summarize, confidence: 0.85, matchedKeywords: [pattern])
            }
        }

        // Reply patterns
        let replyPatterns = ["reply", "respond", "answer", "write back", "message", "draft"]
        for pattern in replyPatterns {
            if normalized.contains(pattern) {
                return IntentClassification(intent: .messageReply, confidence: 0.8, matchedKeywords: [pattern])
            }
        }

        // Explain patterns
        let explainPatterns = ["explain", "what is", "what does", "how does", "understand", "tell me about"]
        for pattern in explainPatterns {
            if normalized.contains(pattern) {
                return IntentClassification(intent: .general, confidence: 0.7, matchedKeywords: [pattern])
            }
        }

        // Default to general
        return IntentClassification(intent: .general, confidence: 0.5)
    }
}
