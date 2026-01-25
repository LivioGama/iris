//
//  SkillRegistry.swift
//  IRIS
//
//  Registry of all available skills that IRIS can perform
//

import Foundation
import IRISCore

/// Central registry of all IRIS skills
/// Maps screen contexts and intents to actionable skills
class SkillRegistry {
    /// Singleton instance
    static let shared = SkillRegistry()

    /// All registered skills
    private(set) var skills: [String: Skill] = [:]

    /// Skill metadata for quick matching (loaded at startup)
    private(set) var metadata: [SkillMetadata] = []

    private init() {
        registerBuiltInSkills()
    }

    // MARK: - Built-in Skills

    private func registerBuiltInSkills() {
        // Code Improvement
        register(Skill(
            id: "code-improvement",
            name: "Code Improvement",
            description: "Refactor, optimize, and improve code quality",
            icon: "wand.and.stars",
            intents: ["improve", "code_improvement", "improve_code", "refactor"],
            capabilities: [.readScreen, .clipboard],
            allowedActions: [.copy, .paste, .typeText],
            canAutoExecute: false,
            autoExecuteThreshold: 0.9,
            instructions: """
            When improving code:
            1. Analyze the visible code for issues
            2. Apply best practices for the detected language
            3. Improve readability and maintainability
            4. Optimize performance where obvious
            5. Keep the same functionality
            """
        ))

        // Bug Fixer
        register(Skill(
            id: "bug-fixer",
            name: "Bug Fixer",
            description: "Find and fix bugs, errors, and issues",
            icon: "ladybug",
            intents: ["fix", "find_bugs", "debug", "bugs"],
            capabilities: [.readScreen, .clipboard, .executeShell],
            allowedActions: [.copy, .paste, .typeText, .runCommand],
            canAutoExecute: false,
            autoExecuteThreshold: 0.85,
            instructions: """
            When fixing bugs:
            1. Identify the error or problem
            2. Analyze root cause
            3. Propose a fix with explanation
            4. Offer to apply the fix
            """
        ))

        // Code Explainer
        register(Skill(
            id: "code-explainer",
            name: "Code Explainer",
            description: "Explain what code does and how it works",
            icon: "book",
            intents: ["explain", "explanation", "what_is_this"],
            capabilities: [.readScreen],
            allowedActions: [.copy, .speak],
            canAutoExecute: true,
            autoExecuteThreshold: 0.8,
            instructions: """
            When explaining code:
            1. Identify the programming language
            2. Explain the overall purpose
            3. Break down key functions/methods
            4. Highlight important patterns
            5. Keep explanations concise but complete
            """
        ))

        // Content Summarizer
        register(Skill(
            id: "content-summarizer",
            name: "Content Summarizer",
            description: "Summarize long text, articles, and documents",
            icon: "doc.text",
            intents: ["summarize", "summary", "tldr"],
            capabilities: [.readScreen, .clipboard],
            allowedActions: [.copy, .speak],
            canAutoExecute: true,
            autoExecuteThreshold: 0.8,
            instructions: """
            When summarizing:
            1. Extract key points
            2. Maintain critical information
            3. Use bullet points for clarity
            4. Keep to 3-5 main points
            5. Include any action items
            """
        ))

        // Message Composer
        register(Skill(
            id: "message-composer",
            name: "Message Composer",
            description: "Draft replies to messages, emails, and chats",
            icon: "bubble.left.and.bubble.right",
            intents: ["reply", "message_reply", "respond"],
            capabilities: [.readScreen, .clipboard, .controlApps, .typeText],
            allowedActions: [.copy, .paste, .typeText, .activateApp],
            canAutoExecute: false,
            autoExecuteThreshold: 0.85,
            instructions: """
            When composing messages:
            1. Understand the context of the conversation
            2. Match the tone of the original message
            3. Be helpful and professional
            4. Keep responses concise
            5. Offer to send or copy the draft
            """
        ))

        // Web Search
        register(Skill(
            id: "web-search",
            name: "Web Search",
            description: "Search the web for information",
            icon: "magnifyingglass",
            intents: ["search"],
            capabilities: [.readScreen, .webSearch],
            allowedActions: [.openUrl],
            canAutoExecute: true,
            autoExecuteThreshold: 0.95,
            instructions: """
            When searching:
            1. Extract the search query from context
            2. Open Google with the query
            3. Can auto-execute for selected text
            """
        ))

        // Code Generator
        register(Skill(
            id: "code-generator",
            name: "Code Generator",
            description: "Generate new code, boilerplate, and templates",
            icon: "curlybraces",
            intents: ["generate", "create_code"],
            capabilities: [.readScreen, .clipboard, .fileSystem],
            allowedActions: [.copy, .paste, .typeText, .writeFile, .createFile],
            canAutoExecute: false,
            autoExecuteThreshold: 0.8,
            instructions: """
            When generating code:
            1. Understand the requirements
            2. Match existing code style if visible
            3. Include comments for clarity
            4. Follow best practices
            5. Offer to copy or insert the code
            """
        ))

        // Translator
        register(Skill(
            id: "translator",
            name: "Translator",
            description: "Translate text between languages",
            icon: "globe",
            intents: ["translate"],
            capabilities: [.readScreen, .clipboard],
            allowedActions: [.copy, .speak],
            canAutoExecute: false,
            autoExecuteThreshold: 0.8,
            instructions: """
            When translating:
            1. Detect source language
            2. Ask for target language if not specified
            3. Preserve formatting and tone
            4. Offer to copy the translation
            """
        ))

        // Data Analyzer
        register(Skill(
            id: "data-analyzer",
            name: "Data Analyzer",
            description: "Analyze data, charts, and spreadsheets",
            icon: "chart.bar",
            intents: ["analyze", "analysis"],
            capabilities: [.readScreen, .clipboard],
            allowedActions: [.copy, .speak],
            canAutoExecute: false,
            autoExecuteThreshold: 0.7,
            instructions: """
            When analyzing data:
            1. Identify the type of data/chart
            2. Extract key metrics and trends
            3. Provide insights and observations
            4. Suggest potential actions
            """
        ))

        // Complete/Autocomplete
        register(Skill(
            id: "completer",
            name: "Autocomplete",
            description: "Complete partial code, text, or forms",
            icon: "text.badge.checkmark",
            intents: ["complete"],
            capabilities: [.readScreen, .clipboard, .typeText],
            allowedActions: [.copy, .paste, .typeText],
            canAutoExecute: false,
            autoExecuteThreshold: 0.85,
            instructions: """
            When completing:
            1. Understand the context
            2. Predict the likely completion
            3. Match existing style
            4. Offer to insert the completion
            """
        ))

        // Build skill metadata for quick lookup
        metadata = skills.values.map { SkillMetadata(from: $0) }
    }

    // MARK: - Registration

    /// Register a new skill
    func register(_ skill: Skill) {
        skills[skill.id] = skill
    }

    /// Unregister a skill
    func unregister(_ skillId: String) {
        skills.removeValue(forKey: skillId)
    }

    // MARK: - Lookup

    /// Get a skill by ID
    func skill(for id: String) -> Skill? {
        skills[id]
    }

    /// Find skills that match an intent
    func skills(for intent: String) -> [Skill] {
        let normalizedIntent = intent.lowercased()
        return skills.values.filter { skill in
            skill.intents.contains { $0.lowercased() == normalizedIntent }
        }
    }

    /// Find the best matching skill for an intent
    func bestSkill(for intent: String) -> Skill? {
        let matches = skills(for: intent)
        // Return the first match (skills are registered in priority order)
        return matches.first
    }

    /// Find skills that have a specific capability
    func skills(with capability: SkillCapability) -> [Skill] {
        skills.values.filter { $0.capabilities.contains(capability) }
    }

    /// Find skills that can perform a specific action
    func skills(canPerform action: SkillActionType) -> [Skill] {
        skills.values.filter { $0.allowedActions.contains(action) }
    }

    // MARK: - Matching

    /// Match a ProactiveSuggestion to a skill and enrich it
    func enrichSuggestion(_ suggestion: ProactiveSuggestion) -> ProactiveSuggestion {
        guard let skill = bestSkill(for: suggestion.intent) else {
            return suggestion
        }

        var enriched = suggestion
        enriched.matchedSkill = skill.id
        enriched.canAct = !skill.allowedActions.isEmpty
        enriched.actionPreview = buildActionPreview(for: skill, suggestion: suggestion)

        return enriched
    }

    /// Build a preview of what action will be taken
    private func buildActionPreview(for skill: Skill, suggestion: ProactiveSuggestion) -> String {
        switch skill.id {
        case "web-search":
            return "Open Google search"
        case "code-improvement":
            return "Improve and copy to clipboard"
        case "bug-fixer":
            return "Analyze and suggest fix"
        case "message-composer":
            return "Draft reply"
        case "content-summarizer":
            return "Summarize key points"
        case "code-explainer":
            return "Explain what this does"
        case "code-generator":
            return "Generate code"
        case "translator":
            return "Translate text"
        case "data-analyzer":
            return "Analyze data"
        case "completer":
            return "Complete text"
        default:
            return "Execute skill"
        }
    }

    // MARK: - Metadata

    /// Get metadata for all skills (for quick display)
    func allMetadata() -> [SkillMetadata] {
        metadata
    }

    /// Get metadata for a specific skill
    func metadata(for skillId: String) -> SkillMetadata? {
        metadata.first { $0.id == skillId }
    }
}

// MARK: - Convenience Extensions

extension SkillRegistry {
    /// Check if a skill ID is registered
    func isRegistered(_ skillId: String) -> Bool {
        skills[skillId] != nil
    }

    /// Get all skill IDs
    var allSkillIds: [String] {
        Array(skills.keys).sorted()
    }

    /// Get skills grouped by capability
    var skillsByCapability: [SkillCapability: [Skill]] {
        var result: [SkillCapability: [Skill]] = [:]
        for capability in SkillCapability.allCases {
            result[capability] = skills(with: capability)
        }
        return result
    }
}
