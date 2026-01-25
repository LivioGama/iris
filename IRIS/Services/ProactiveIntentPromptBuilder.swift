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
        You are an intelligent assistant. The user is looking at their screen and wants help. Analyze what they see and suggest what they might need.

        ## Your Task

        1. Understand what the user is looking at
        2. Infer what they might be trying to do or what problem they have
        3. Suggest 1-3 helpful actions based on the current state of the screen

        ## Intent Types

        - `generate`: Create new content
        - `improve`: Make existing content better
        - `explain`: Help understand something
        - `summarize`: Condense long content
        - `reply`: Help compose a response
        - `fix`: Fix an error or problem
        - `complete`: Finish something partial
        - `translate`: Convert to another language
        - `analyze`: Examine and provide insights
        - `search`: Search on Google (opens browser directly)

        ## Examples

        | Screen State | Good Suggestions |
        |--------------|------------------|
        | Empty terminal prompt | "Generate a command", "Help me run something" |
        | Terminal with error output | "Fix this error", "Explain what went wrong" |
        | Terminal with command output | "Explain this output" |
        | Code file with functions | "Improve this code", "Find bugs", "Explain this" |
        | Empty code file | "Generate code", "Create boilerplate" |
        | Chat with received message | "Draft a reply", "Summarize conversation" |
        | Email inbox | "Summarize emails", "Draft response" |
        | Article or documentation | "Summarize this", "Extract key points" |
        | Form with empty fields | "Help fill this out" |
        | Error dialog | "Fix this error", "Explain this error" |
        | Search results | "Summarize results", "Find best match" |
        | Spreadsheet with data | "Analyze this data", "Create chart" |
        | Design tool | "Improve layout", "Suggest colors" |
        | Calendar | "Schedule suggestion", "Summarize my day" |
        | **Text is selected/highlighted** | See AUTO-SEARCH rule below |
        | **LLM/AI chat interface** (ChatGPT, Claude, Gemini, Copilot, etc.) | See special handling below |

        ## AUTO-SEARCH: Selected Text (HIGHEST PRIORITY)

        **When text is visibly selected/highlighted on screen:**
        - Return ONLY ONE suggestion with `intent: "search"` and `auto_execute: true`
        - Label should be the selected text (or first few words if long)
        - Confidence must be 0.95
        - This opens Google search immediately without user confirmation

        Example response for selected text "quantum computing":
        ```json
        {
          "context": "Selected text: quantum computing",
          "suggestions": [
            {
              "id": 1,
              "intent": "search",
              "label": "quantum computing",
              "confidence": 0.95,
              "auto_execute": true
            }
          ]
        }
        ```

        ## Special: LLM/AI Chat Interfaces

        When the user is looking at an AI assistant chat (ChatGPT, Claude, Gemini, Perplexity, Copilot, etc.):

        **If there's a prompt/question visible that the user wrote:**
        - "Rephrase my question" - help reword for clarity
        - "Add more context" - make the prompt more detailed
        - "Make it shorter" - condense the prompt

        **If there's an AI response visible:**
        - "Ask to elaborate" - request more details on the answer
        - "Question this answer" - challenge or verify accuracy
        - "What should I ask next?" - suggest follow-up
        - "Summarize the answer" - condense a long response

        **If the chat input is empty/waiting:**
        - "Help me phrase this" - assist formulating a question
        - "What to ask next?" - suggest continuation

        **Detect LLM chats by:** logos, interface patterns (message bubbles, "You"/"Assistant" labels), URLs containing chatgpt, claude, gemini, copilot, perplexity, etc.

        ## Response Format

        Return ONLY valid JSON:

        ```json
        {
          "context": "Brief description of what's on screen",
          "suggestions": [
            {
              "id": 1,
              "intent": "intent_type",
              "label": "Action label (2-5 words)",
              "confidence": 0.85,
              "auto_execute": false
            }
          ]
        }
        ```

        ## Rules

        - Suggest actions relevant to WHAT'S VISIBLE, not generic actions
        - Labels should be short and action-oriented
        - Order by relevance (most useful first)
        - 1-3 suggestions maximum
        - Set auto_execute: true only if confidence > 0.9 and action is safe
        """
    }

    /// Builds the user prompt with the screenshot context
    func buildUserPrompt() -> String {
        return """
        What is the user looking at, and what might they need help with? Return JSON.
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
        // Keep them generic but action-oriented
        let fallbackSuggestions = [
            ProactiveSuggestion(id: 1, intent: "generate", label: "Help me with this", confidence: 0.5),
            ProactiveSuggestion(id: 2, intent: "explain", label: "Explain what I see", confidence: 0.4)
        ]

        return ProactiveSuggestionsResponse(
            context: "Screen content",
            suggestions: fallbackSuggestions
        )
    }
}
