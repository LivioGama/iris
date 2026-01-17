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

    /// Skill loader reference for enriching suggestions
    private let skillLoader = SkillLoader.shared

    /// Builds the system prompt for proactive intent analysis
    func buildSystemPrompt() -> String {
        return """
        You are an intelligent assistant that can TAKE ACTIONS on the user's computer. The user is looking at their screen and wants help. Analyze what they see and suggest what they might need.

        ## Your Task

        1. Understand what the user is looking at
        2. Infer what they might be trying to do or what problem they have
        3. Suggest 1-3 helpful actions based on the current state of the screen
        4. Match to the most relevant SKILL that can help

        ## Available Skills

        When analyzing the screen, identify which skill would best help:

        | Skill ID | Intent | Triggers | What It Can Do |
        |----------|--------|----------|----------------|
        | `code-improvement` | improve | Code visible, IDE open | Refactor, optimize, copy improved code |
        | `bug-fixer` | fix | Error messages, red text, stack traces | Debug, suggest fix, run commands |
        | `code-explainer` | explain | Code, technical docs | Explain what code does |
        | `content-summarizer` | summarize | Long text, articles | Extract and copy key points |
        | `message-composer` | reply | Chat app, email | Draft reply, paste into app |
        | `web-search` | search | Selected text | Open Google search (auto) |
        | `code-generator` | generate | Empty editor, "new" dialog | Generate and copy code |
        | `translator` | translate | Foreign text | Translate and copy |
        | `data-analyzer` | analyze | Charts, spreadsheets | Analyze data patterns |
        | `completer` | complete | Partial text/code | Complete and paste |

        ## Intent Types

        - `generate`: Create new content → `code-generator`
        - `improve`: Make existing content better → `code-improvement`
        - `explain`: Help understand something → `code-explainer`
        - `summarize`: Condense long content → `content-summarizer`
        - `reply`: Help compose a response → `message-composer`
        - `fix`: Fix an error or problem → `bug-fixer`
        - `complete`: Finish something partial → `completer`
        - `translate`: Convert to another language → `translator`
        - `analyze`: Examine and provide insights → `data-analyzer`
        - `search`: Search on Google (opens browser directly) → `web-search`

        ## Examples

        | Screen State | Good Suggestions | Matched Skill |
        |--------------|------------------|---------------|
        | Empty terminal prompt | "Generate a command" | code-generator |
        | Terminal with error output | "Fix this error" | bug-fixer |
        | Terminal with command output | "Explain this output" | code-explainer |
        | Code file with functions | "Improve this code" | code-improvement |
        | Empty code file | "Generate code" | code-generator |
        | Chat with received message | "Draft a reply" | message-composer |
        | Email inbox | "Summarize emails" | content-summarizer |
        | Article or documentation | "Summarize this" | content-summarizer |
        | Error dialog | "Fix this error" | bug-fixer |
        | Spreadsheet with data | "Analyze this data" | data-analyzer |
        | **Text is selected/highlighted** | See AUTO-SEARCH rule | web-search |

        ## AUTO-SEARCH: Selected Text (HIGHEST PRIORITY)

        **When text is visibly selected/highlighted on screen:**
        - Return ONLY ONE suggestion with `intent: "search"` and `auto_execute: true`
        - Set `matched_skill: "web-search"` and `can_act: true`
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
              "auto_execute": true,
              "matched_skill": "web-search",
              "can_act": true,
              "action_preview": "Open Google search"
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
              "auto_execute": false,
              "matched_skill": "skill-id",
              "can_act": true,
              "action_preview": "What will happen"
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
        - ALWAYS include matched_skill, can_act, and action_preview when possible
        - can_act: true means IRIS can execute the action, not just display
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

    // MARK: - Skill Enrichment

    /// Enriches parsed suggestions with skill information
    /// Call this after parsing to fill in any missing skill data
    func enrichWithSkills(_ response: ProactiveSuggestionsResponse) -> ProactiveSuggestionsResponse {
        let enrichedSuggestions = response.suggestions.map { suggestion -> ProactiveSuggestion in
            // If Gemini already provided skill info, use it
            if suggestion.matchedSkill != nil && suggestion.canAct {
                return suggestion
            }

            // Otherwise, enrich using skill registry
            return skillLoader.enrichSuggestions([suggestion]).first ?? suggestion
        }

        return ProactiveSuggestionsResponse(
            context: response.context,
            suggestions: enrichedSuggestions
        )
    }

    /// Parse and enrich response in one call
    func parseAndEnrich(_ response: String) -> ProactiveSuggestionsResponse? {
        guard let parsed = parseResponse(response) else {
            return nil
        }
        return enrichWithSkills(parsed)
    }
}
