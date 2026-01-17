//
//  Skill.swift
//  IRISCore
//
//  Model for agentic skills that define what IRIS can do
//

import Foundation

// MARK: - Enums (must be declared before structs that use them)

/// Capabilities a skill can have
public enum SkillCapability: String, Codable, CaseIterable {
    /// Can analyze screenshot content
    case readScreen = "read_screen"

    /// Can execute shell commands
    case executeShell = "execute_shell"

    /// Can control apps via AppleScript
    case controlApps = "control_apps"

    /// Can perform web searches
    case webSearch = "web_search"

    /// Can read/write clipboard
    case clipboard = "clipboard"

    /// Can read/write files
    case fileSystem = "file_system"

    /// Can make HTTP API requests
    case apiCalls = "api_calls"

    /// Can type text into apps
    case typeText = "type_text"
}

/// Types of actions IRIS can perform
public enum SkillActionType: String, Codable, CaseIterable {
    // Clipboard actions
    case copy
    case paste

    // Input actions
    case typeText = "type_text"
    case click
    case pressKey = "press_key"

    // App actions
    case openUrl = "open_url"
    case openApp = "open_app"
    case activateApp = "activate_app"

    // Shell actions
    case runCommand = "run_command"
    case runScript = "run_script"

    // File actions
    case readFile = "read_file"
    case writeFile = "write_file"
    case createFile = "create_file"

    // API actions
    case httpRequest = "http_request"

    // System actions
    case notify = "notify"
    case speak = "speak"
    
    // UI actions
    case scroll = "scroll"
}

// MARK: - Core Structs

/// A skill defines a capability IRIS can perform based on screen context
public struct Skill: Identifiable, Codable {
    /// Unique identifier (e.g., "code-improvement")
    public let id: String

    /// Display name (e.g., "Code Improvement")
    public let name: String

    /// Description of what this skill does and when to use it
    public let description: String

    /// SF Symbol icon name
    public let icon: String

    /// Intent types this skill handles (from ProactiveSuggestion)
    public let intents: [String]

    /// Capabilities required for this skill
    public let capabilities: [SkillCapability]

    /// Actions this skill is allowed to perform
    public let allowedActions: [SkillActionType]

    /// Whether this skill can auto-execute at high confidence
    public let canAutoExecute: Bool

    /// Minimum confidence threshold for auto-execution (0.0-1.0)
    public let autoExecuteThreshold: Double

    /// Instructions for how to use this skill (loaded on demand)
    public var instructions: String?

    public init(
        id: String,
        name: String,
        description: String,
        icon: String = "sparkles",
        intents: [String],
        capabilities: [SkillCapability],
        allowedActions: [SkillActionType],
        canAutoExecute: Bool = false,
        autoExecuteThreshold: Double = 0.9,
        instructions: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.intents = intents
        self.capabilities = capabilities
        self.allowedActions = allowedActions
        self.canAutoExecute = canAutoExecute
        self.autoExecuteThreshold = autoExecuteThreshold
        self.instructions = instructions
    }

    // Coding keys for JSON serialization
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, intents, capabilities
        case allowedActions = "allowed_actions"
        case canAutoExecute = "can_auto_execute"
        case autoExecuteThreshold = "auto_execute_threshold"
        case instructions
    }
}

/// A concrete action to be executed
public struct Action: Identifiable, Codable {
    public let id: UUID
    public let type: SkillActionType
    public let parameters: [String: String]
    public let description: String
    public let requiresConfirmation: Bool

    public init(
        id: UUID = UUID(),
        type: SkillActionType,
        parameters: [String: String] = [:],
        description: String,
        requiresConfirmation: Bool = false
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.description = description
        self.requiresConfirmation = requiresConfirmation
    }

    // Convenience initializers for common actions

    public static func copy(_ text: String) -> Action {
        Action(
            type: .copy,
            parameters: ["text": text],
            description: "Copy to clipboard"
        )
    }

    public static func paste() -> Action {
        Action(
            type: .paste,
            parameters: [:],
            description: "Paste from clipboard"
        )
    }

    public static func typeText(_ text: String, appName: String? = nil) -> Action {
        var params = ["text": text]
        if let app = appName {
            params["app"] = app
        }
        return Action(
            type: .typeText,
            parameters: params,
            description: "Type text\(appName.map { " into \($0)" } ?? "")"
        )
    }

    public static func openUrl(_ url: String) -> Action {
        Action(
            type: .openUrl,
            parameters: ["url": url],
            description: "Open \(url)"
        )
    }

    public static func openApp(_ bundleId: String) -> Action {
        Action(
            type: .openApp,
            parameters: ["bundle_id": bundleId],
            description: "Open app"
        )
    }

    public static func runCommand(_ command: String, requiresConfirmation: Bool = true) -> Action {
        Action(
            type: .runCommand,
            parameters: ["command": command],
            description: "Run: \(command.prefix(50))\(command.count > 50 ? "..." : "")",
            requiresConfirmation: requiresConfirmation
        )
    }

    public static func notify(_ message: String, title: String = "IRIS") -> Action {
        Action(
            type: .notify,
            parameters: ["message": message, "title": title],
            description: "Show notification"
        )
    }

    public static func speak(_ text: String) -> Action {
        Action(
            type: .speak,
            parameters: ["text": text],
            description: "Speak aloud"
        )
    }
    
    public static func scroll(direction: String = "down", amount: Int = 5) -> Action {
        Action(
            type: .scroll,
            parameters: ["direction": direction, "amount": String(amount)],
            description: "Scroll \(direction) by \(amount)"
        )
    }
}

/// Result of executing an action
public struct ActionResult: Codable {
    public let action: Action
    public let success: Bool
    public let output: String?
    public let error: String?
    public let timestamp: Date

    public init(
        action: Action,
        success: Bool,
        output: String? = nil,
        error: String? = nil,
        timestamp: Date = Date()
    ) {
        self.action = action
        self.success = success
        self.output = output
        self.error = error
        self.timestamp = timestamp
    }

    public static func success(_ action: Action, output: String? = nil) -> ActionResult {
        ActionResult(action: action, success: true, output: output)
    }

    public static func failure(_ action: Action, error: String) -> ActionResult {
        ActionResult(action: action, success: false, error: error)
    }
}

/// A single step in an action plan
public struct ActionStep: Identifiable, Codable {
    public let id: UUID
    public let description: String
    public let action: Action
    public let fallbackAction: Action?

    public init(
        id: UUID = UUID(),
        description: String,
        action: Action,
        fallbackAction: Action? = nil
    ) {
        self.id = id
        self.description = description
        self.action = action
        self.fallbackAction = fallbackAction
    }
}

/// A plan consisting of multiple actions
public struct ActionPlan: Identifiable, Codable {
    public let id: UUID
    public let skillId: String
    public let description: String
    public let steps: [ActionStep]
    public let requiresConfirmation: Bool

    public init(
        id: UUID = UUID(),
        skillId: String,
        description: String,
        steps: [ActionStep],
        requiresConfirmation: Bool = true
    ) {
        self.id = id
        self.skillId = skillId
        self.description = description
        self.steps = steps
        self.requiresConfirmation = requiresConfirmation
    }

    /// Total number of actions across all steps
    public var totalActions: Int {
        steps.count
    }

    /// Whether any step requires confirmation
    public var hasConfirmationRequired: Bool {
        requiresConfirmation || steps.contains { $0.action.requiresConfirmation }
    }
}

/// Result of executing an entire plan
public struct ExecutionResult: Codable {
    public let plan: ActionPlan
    public let results: [ActionResult]
    public let overallSuccess: Bool
    public let startTime: Date
    public let endTime: Date

    public init(
        plan: ActionPlan,
        results: [ActionResult],
        overallSuccess: Bool,
        startTime: Date,
        endTime: Date
    ) {
        self.plan = plan
        self.results = results
        self.overallSuccess = overallSuccess
        self.startTime = startTime
        self.endTime = endTime
    }

    /// Duration of execution
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Number of successful actions
    public var successCount: Int {
        results.filter { $0.success }.count
    }

    /// Number of failed actions
    public var failureCount: Int {
        results.filter { !$0.success }.count
    }
}

/// Metadata for a skill (loaded at startup for quick matching)
public struct SkillMetadata: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let intents: [String]
    public let capabilities: [SkillCapability]

    public init(from skill: Skill) {
        self.id = skill.id
        self.name = skill.name
        self.description = skill.description
        self.icon = skill.icon
        self.intents = skill.intents
        self.capabilities = skill.capabilities
    }

    public init(
        id: String,
        name: String,
        description: String,
        icon: String,
        intents: [String],
        capabilities: [SkillCapability]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.intents = intents
        self.capabilities = capabilities
    }
}
