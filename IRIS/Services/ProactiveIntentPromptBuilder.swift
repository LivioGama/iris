//
//  ProactiveIntentPromptBuilder.swift
//  IRIS
//
//  Builds prompts for proactive screenshot analysis and intent prediction
//

import Foundation
import IRISCore

/// Builds prompts for Gemini to analyze screenshots and suggest likely user intents
class ProactiveIntentPromptBuilder {

    /// Builds the system prompt for proactive intent analysis
    func buildSystemPrompt() -> String {
        return """
        You are an intelligent assistant that analyzes screenshots to predict what the user might want to do.

        Your task is to:
        1. Analyze the screenshot content (application, visible text, UI elements, context)
        2. Predict 1-3 most likely actions the user might want to take
        3. Return your analysis in a specific JSON format

        ## Guidelines for Suggestions

        - Suggest actions that are CONTEXTUALLY RELEVANT to what's visible
        - Order suggestions by likelihood (most likely first)
        - Use clear, concise labels that describe the action
        - Set confidence scores based on how obvious the intent is:
          - 0.8-1.0: Very obvious intent (e.g., code visible → "Improve this code")
          - 0.5-0.8: Likely intent based on context
          - 0.3-0.5: Possible but less certain

        ## Intent Types

        Use these intent identifiers:
        - `code_improvement`: For code that could be improved/refactored
        - `explain`: To explain what something does or means
        - `summarize`: To summarize content (articles, documents, long text)
        - `reply`: To help compose a reply to a message
        - `find_bugs`: To find bugs or issues in code
        - `translate`: To translate text to another language
        - `analyze`: General analysis of content

        ## Response Format

        You MUST respond with ONLY valid JSON in this exact format:

        ```json
        {
          "context": "Brief description of what's on screen",
          "suggestions": [
            {
              "id": 1,
              "intent": "intent_type",
              "label": "User-friendly action label",
              "confidence": 0.85,
              "auto_execute": false
            }
          ]
        }
        ```

        IMPORTANT:
        - Return ONLY the JSON, no other text
        - Always include 1-3 suggestions
        - Labels should be SHORT (2-5 words)
        - Set auto_execute to true ONLY if confidence > 0.9 AND the action is safe
        """
    }

    /// Builds the user prompt with the screenshot context
    func buildUserPrompt() -> String {
        return """
        Analyze this screenshot and suggest what the user might want to do.

        Consider:
        - What application or content is visible?
        - Is there code, text, messages, or other content?
        - What are the most useful actions for this context?

        Return your suggestions as JSON.
        """
    }

    /// Parses the JSON response from Gemini into ProactiveSuggestionsResponse
    func parseResponse(_ response: String) -> ProactiveSuggestionsResponse? {
        // Try to extract JSON from the response
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code block if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }

        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }

        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to parse JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ ProactiveIntentPromptBuilder: Failed to convert response to data")
            return nil
        }

        do {
            let decoded = try JSONDecoder().decode(ProactiveSuggestionsResponse.self, from: jsonData)
            print("✅ ProactiveIntentPromptBuilder: Parsed \(decoded.suggestions.count) suggestions")
            return decoded
        } catch {
            print("❌ ProactiveIntentPromptBuilder: JSON parsing failed: \(error)")
            print("❌ Raw JSON: \(jsonString.prefix(500))")

            // Try to create a fallback response
            return createFallbackResponse(from: response)
        }
    }

    /// Creates a fallback response when JSON parsing fails
    private func createFallbackResponse(from response: String) -> ProactiveSuggestionsResponse {
        // Default suggestions when we can't parse Gemini's response
        let fallbackSuggestions = [
            ProactiveSuggestion(id: 1, intent: "explain", label: "Explain this", confidence: 0.6),
            ProactiveSuggestion(id: 2, intent: "summarize", label: "Summarize", confidence: 0.5),
            ProactiveSuggestion(id: 3, intent: "analyze", label: "Analyze", confidence: 0.4)
        ]

        return ProactiveSuggestionsResponse(
            context: "Unable to analyze screenshot",
            suggestions: fallbackSuggestions
        )
    }
}
