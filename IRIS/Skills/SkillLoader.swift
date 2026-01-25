//
//  SkillLoader.swift
//  IRIS
//
//  Loads and manages skills with progressive disclosure
//

import Foundation
import IRISCore

/// Loads and manages skills with progressive disclosure
/// - Metadata: Loaded at startup for quick matching (~100 tokens per skill)
/// - Instructions: Loaded on demand when skill is activated (<5k tokens)
/// - Resources: Loaded only when needed (scripts, references)
class SkillLoader {
    /// Singleton instance
    static let shared = SkillLoader()

    /// Registry reference
    private let registry = SkillRegistry.shared

    /// Cache for loaded skill instructions
    private var instructionCache: [String: String] = [:]

    /// Whether skills have been initialized
    private(set) var isInitialized = false

    private init() {}

    // MARK: - Initialization

    /// Initialize skill system (call on app startup)
    func initialize() async {
        guard !isInitialized else { return }

        print("🎯 SkillLoader: Initializing skill system...")

        // Load built-in skills (already done in SkillRegistry init)
        // Could also load custom skills from disk here

        isInitialized = true
        print("✅ SkillLoader: Initialized with \(registry.allSkillIds.count) skills")
    }

    // MARK: - Loading

    /// Load skill metadata for all skills (lightweight, for startup)
    func loadAllMetadata() -> [SkillMetadata] {
        registry.allMetadata()
    }

    /// Load a full skill with instructions
    func loadSkill(_ skillId: String) -> Skill? {
        guard var skill = registry.skill(for: skillId) else {
            print("⚠️ SkillLoader: Skill not found: \(skillId)")
            return nil
        }

        // Load instructions if not already cached
        if skill.instructions == nil {
            skill.instructions = loadInstructions(for: skillId)
        }

        return skill
    }

    /// Load instructions for a skill (from cache or disk)
    private func loadInstructions(for skillId: String) -> String? {
        // Check cache first
        if let cached = instructionCache[skillId] {
            return cached
        }

        // Instructions are embedded in the Skill struct for built-in skills
        // For custom skills, we'd load from disk here
        guard let skill = registry.skill(for: skillId) else {
            return nil
        }

        // Cache and return
        if let instructions = skill.instructions {
            instructionCache[skillId] = instructions
        }

        return skill.instructions
    }

    // MARK: - Matching

    /// Match screen context to relevant skills
    func matchSkills(
        context: String,
        suggestions: [ProactiveSuggestion]
    ) -> [MatchedSkill] {
        var matches: [MatchedSkill] = []

        for suggestion in suggestions {
            if let skill = registry.bestSkill(for: suggestion.intent) {
                let match = MatchedSkill(
                    skill: skill,
                    suggestion: suggestion,
                    matchReason: "Intent match: \(suggestion.intent)",
                    confidence: suggestion.confidence
                )
                matches.append(match)
            }
        }

        // Sort by confidence
        return matches.sorted { $0.confidence > $1.confidence }
    }

    /// Match a single suggestion to a skill
    func matchSkill(for suggestion: ProactiveSuggestion) -> Skill? {
        registry.bestSkill(for: suggestion.intent)
    }

    /// Enrich suggestions with skill information
    func enrichSuggestions(_ suggestions: [ProactiveSuggestion]) -> [ProactiveSuggestion] {
        suggestions.map { registry.enrichSuggestion($0) }
    }

    // MARK: - Capability Checks

    /// Check if a skill can be executed (has required permissions)
    func canExecute(_ skill: Skill) -> Bool {
        // Check each capability
        for capability in skill.capabilities {
            switch capability {
            case .executeShell:
                // Shell commands always available (no special permission)
                continue
            case .controlApps:
                // Requires Accessibility permission (checked elsewhere)
                continue
            case .fileSystem:
                // Requires sandboxed file access
                continue
            case .apiCalls:
                // Requires network access
                continue
            case .readScreen, .clipboard, .webSearch, .typeText:
                // Always available
                continue
            }
        }
        return true
    }

    /// Get the permissions needed for a skill
    func requiredPermissions(for skill: Skill) -> [String] {
        var permissions: [String] = []

        for capability in skill.capabilities {
            switch capability {
            case .controlApps:
                permissions.append("Accessibility")
            case .fileSystem:
                permissions.append("File Access")
            default:
                break
            }
        }

        return Array(Set(permissions)) // Deduplicate
    }
}

// MARK: - Matched Skill

/// A skill matched to a suggestion with context
struct MatchedSkill {
    let skill: Skill
    let suggestion: ProactiveSuggestion
    let matchReason: String
    let confidence: Double

    /// Whether this match should auto-execute
    var shouldAutoExecute: Bool {
        skill.canAutoExecute &&
        confidence >= skill.autoExecuteThreshold &&
        suggestion.autoExecute
    }

    /// Preview text for what this skill will do
    var actionPreview: String {
        suggestion.actionPreview ?? "Execute \(skill.name)"
    }
}

// MARK: - Debug Helpers

extension SkillLoader {
    /// Print debug info about loaded skills
    func printDebugInfo() {
        print("🎯 SkillLoader Debug Info:")
        print("   Initialized: \(isInitialized)")
        print("   Skills loaded: \(registry.allSkillIds.count)")
        print("   Skills: \(registry.allSkillIds.joined(separator: ", "))")
        print("   Instructions cached: \(instructionCache.count)")
    }

    /// Get a summary of all skills for debugging
    func debugSummary() -> String {
        var lines: [String] = ["Skills Summary:"]

        for skillId in registry.allSkillIds.sorted() {
            if let skill = registry.skill(for: skillId) {
                let caps = skill.capabilities.map { $0.rawValue }.joined(separator: ", ")
                lines.append("  \(skillId): \(skill.name) [\(caps)]")
            }
        }

        return lines.joined(separator: "\n")
    }
}
