//
//  ProactiveSuggestion.swift
//  IRISCore
//
//  Model for proactive intent suggestions from Gemini
//

import Foundation

/// A single proactive suggestion from Gemini based on screenshot analysis
public struct ProactiveSuggestion: Identifiable, Codable, Equatable {
    public let id: Int
    public let intent: String
    public let label: String
    public let confidence: Double
    public let autoExecute: Bool

    // MARK: - Skill Integration Fields

    /// ID of the skill that matches this suggestion (e.g., "code-improvement")
    public var matchedSkill: String?

    /// Whether IRIS can take action on this suggestion (not just display)
    public var canAct: Bool

    /// Preview of what will happen if this suggestion is executed
    public var actionPreview: String?

    public init(
        id: Int,
        intent: String,
        label: String,
        confidence: Double,
        autoExecute: Bool = false,
        matchedSkill: String? = nil,
        canAct: Bool = false,
        actionPreview: String? = nil
    ) {
        self.id = id
        self.intent = intent
        self.label = label
        self.confidence = confidence
        self.autoExecute = autoExecute
        self.matchedSkill = matchedSkill
        self.canAct = canAct
        self.actionPreview = actionPreview
    }

    enum CodingKeys: String, CodingKey {
        case id
        case intent
        case label
        case confidence
        case autoExecute = "auto_execute"
        case matchedSkill = "matched_skill"
        case canAct = "can_act"
        case actionPreview = "action_preview"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        intent = try container.decode(String.self, forKey: .intent)
        label = try container.decode(String.self, forKey: .label)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5
        autoExecute = try container.decodeIfPresent(Bool.self, forKey: .autoExecute) ?? false
        matchedSkill = try container.decodeIfPresent(String.self, forKey: .matchedSkill)
        canAct = try container.decodeIfPresent(Bool.self, forKey: .canAct) ?? false
        actionPreview = try container.decodeIfPresent(String.self, forKey: .actionPreview)
    }

    // MARK: - Skill Helpers

    /// Returns true if this suggestion should show the execute button
    public var showsExecuteButton: Bool {
        canAct && matchedSkill != nil
    }

    /// Returns true if this suggestion can auto-execute (high confidence + can act)
    public var shouldAutoExecute: Bool {
        autoExecute && canAct && confidence >= 0.9
    }
}

/// Response container for proactive suggestions
public struct ProactiveSuggestionsResponse: Codable {
    public let context: String
    public let suggestions: [ProactiveSuggestion]

    public init(context: String, suggestions: [ProactiveSuggestion]) {
        self.context = context
        self.suggestions = suggestions
    }
}

/// Maps suggestion intents to ICOIIntent for execution
public extension ProactiveSuggestion {
    /// Convert the string intent to ICOIIntent enum
    var icoiIntent: ICOIIntent {
        switch intent.lowercased() {
        case "code_improvement", "improve_code", "refactor":
            return .codeImprovement
        case "explain", "explanation", "what_is_this":
            return .general // Use general for explanations
        case "summarize", "summary", "tldr":
            return .summarize
        case "reply", "message_reply", "respond":
            return .messageReply
        case "find_bugs", "debug", "bugs":
            return .codeImprovement // Use code improvement for bug finding
        case "translate":
            return .general // No specific intent, use general
        case "analyze", "analysis":
            return .general
        case "search":
            return .general // Search is handled specially
        default:
            return .general
        }
    }

    /// Whether this suggestion should open browser directly (no Gemini call)
    var isDirectBrowserAction: Bool {
        return intent.lowercased() == "search"
    }

    /// Get a prompt to send to Gemini for this suggestion
    var executionPrompt: String {
        switch intent.lowercased() {
        case "code_improvement", "improve_code", "refactor":
            return "Please improve this code - make it cleaner, more efficient, and follow best practices."
        case "explain", "explanation", "what_is_this":
            return "Please explain what I'm looking at. What does this do and how does it work?"
        case "summarize", "summary", "tldr":
            return "Please summarize the key points of what's shown here."
        case "reply", "message_reply", "respond":
            return "What should I reply to this message?"
        case "find_bugs", "debug", "bugs":
            return "Please analyze this code for potential bugs, issues, or improvements."
        case "translate":
            return "Please translate this text."
        case "analyze", "analysis":
            return "Please analyze what's shown on screen and provide insights."
        case "search":
            return label // The label contains the search query context
        default:
            return label // Use the label as the prompt for unknown intents
        }
    }
}
