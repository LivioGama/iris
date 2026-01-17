//
//  ActionPlanner.swift
//  IRIS
//
//  Plans and coordinates action execution for skills
//

import Foundation
import IRISCore

/// Plans and coordinates action execution for skills
/// Given a skill, context, and user request, generates an action plan
class ActionPlanner {
    /// Singleton instance
    static let shared = ActionPlanner()

    /// Action executor
    private let executor = ActionExecutor.shared

    /// Skill loader
    private let skillLoader = SkillLoader.shared

    /// Whether planning is in progress
    private(set) var isPlanning = false

    /// Whether execution is in progress
    private(set) var isExecuting = false

    /// Current plan being executed
    private(set) var currentPlan: ActionPlan?

    /// Progress callback
    var onProgress: ((String) -> Void)?

    /// Completion callback
    var onComplete: ((ExecutionResult) -> Void)?

    private init() {}

    // MARK: - Plan Generation

    /// Generate an action plan for a skill and context
    func planActions(
        skill: Skill,
        context: ScreenContext,
        userRequest: String?,
        geminiResponse: String?
    ) async throws -> ActionPlan {
        isPlanning = true
        defer { isPlanning = false }

        onProgress?("Planning actions for \(skill.name)...")

        var steps: [ActionStep] = []
        var requiresConfirmation = false

        // Generate plan based on skill type
        switch skill.id {
        case "web-search":
            steps = planWebSearch(context: context, userRequest: userRequest)

        case "code-improvement":
            steps = planCodeImprovement(context: context, geminiResponse: geminiResponse)
            requiresConfirmation = true

        case "bug-fixer":
            steps = planBugFix(context: context, geminiResponse: geminiResponse)
            requiresConfirmation = true

        case "message-composer":
            steps = planMessageCompose(context: context, geminiResponse: geminiResponse)
            requiresConfirmation = true

        case "content-summarizer":
            steps = planSummarize(context: context, geminiResponse: geminiResponse)

        case "code-explainer":
            steps = planExplain(context: context, geminiResponse: geminiResponse)

        case "code-generator":
            steps = planCodeGeneration(context: context, geminiResponse: geminiResponse)
            requiresConfirmation = true

        case "translator":
            steps = planTranslate(context: context, geminiResponse: geminiResponse)

        case "data-analyzer":
            steps = planDataAnalysis(context: context, geminiResponse: geminiResponse)

        case "completer":
            steps = planCompletion(context: context, geminiResponse: geminiResponse)

        default:
            steps = planGeneric(skill: skill, context: context, geminiResponse: geminiResponse)
        }

        let plan = ActionPlan(
            skillId: skill.id,
            description: "Execute \(skill.name)",
            steps: steps,
            requiresConfirmation: requiresConfirmation
        )

        currentPlan = plan
        return plan
    }

    // MARK: - Plan Execution

    /// Execute a plan
    func executePlan(_ plan: ActionPlan) async throws -> ExecutionResult {
        isExecuting = true
        currentPlan = plan
        defer {
            isExecuting = false
            currentPlan = nil
        }

        onProgress?("Executing plan: \(plan.description)")

        let result = try await executor.execute(plan)

        onComplete?(result)
        return result
    }

    /// Execute a single action (convenience method)
    func executeAction(_ action: Action) async throws -> ActionResult {
        return try await executor.execute(action)
    }

    /// Cancel current execution
    func cancel() {
        isPlanning = false
        isExecuting = false
        currentPlan = nil
    }

    // MARK: - Skill-Specific Planning

    private func planWebSearch(context: ScreenContext, userRequest: String?) -> [ActionStep] {
        let query = userRequest ?? context.selectedText ?? context.description
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        return [
            ActionStep(
                description: "Open Google search",
                action: Action.openUrl("https://www.google.com/search?q=\(encoded)")
            )
        ]
    }

    private func planCodeImprovement(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No improvement generated",
                    action: Action.notify("No code improvement available")
                )
            ]
        }

        return [
            ActionStep(
                description: "Copy improved code to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Improved code copied to clipboard")
            )
        ]
    }

    private func planBugFix(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No fix generated",
                    action: Action.notify("No bug fix available")
                )
            ]
        }

        return [
            ActionStep(
                description: "Copy fix to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Bug fix copied to clipboard")
            )
        ]
    }

    private func planMessageCompose(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No message composed",
                    action: Action.notify("No message draft available")
                )
            ]
        }

        // Plan: Copy to clipboard, optionally paste
        return [
            ActionStep(
                description: "Copy message draft to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Message draft copied - paste to send")
            )
        ]
    }

    private func planSummarize(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No summary generated",
                    action: Action.notify("No summary available")
                )
            ]
        }

        return [
            ActionStep(
                description: "Copy summary to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Summary copied to clipboard")
            )
        ]
    }

    private func planExplain(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No explanation generated",
                    action: Action.notify("No explanation available")
                )
            ]
        }

        // For explanations, we might want to speak them
        return [
            ActionStep(
                description: "Copy explanation to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Explanation copied to clipboard")
            )
        ]
    }

    private func planCodeGeneration(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No code generated",
                    action: Action.notify("No code generated")
                )
            ]
        }

        return [
            ActionStep(
                description: "Copy generated code to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Generated code copied to clipboard")
            )
        ]
    }

    private func planTranslate(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No translation generated",
                    action: Action.notify("No translation available")
                )
            ]
        }

        return [
            ActionStep(
                description: "Copy translation to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Translation copied to clipboard")
            )
        ]
    }

    private func planDataAnalysis(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No analysis generated",
                    action: Action.notify("No analysis available")
                )
            ]
        }

        return [
            ActionStep(
                description: "Copy analysis to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Analysis copied to clipboard")
            )
        ]
    }

    private func planCompletion(context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No completion generated",
                    action: Action.notify("No completion available")
                )
            ]
        }

        return [
            ActionStep(
                description: "Copy completion to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Completion copied to clipboard")
            )
        ]
    }

    private func planGeneric(skill: Skill, context: ScreenContext, geminiResponse: String?) -> [ActionStep] {
        guard let response = geminiResponse, !response.isEmpty else {
            return [
                ActionStep(
                    description: "No response generated",
                    action: Action.notify("No response available")
                )
            ]
        }

        // Default: copy response to clipboard
        return [
            ActionStep(
                description: "Copy response to clipboard",
                action: Action.copy(response)
            ),
            ActionStep(
                description: "Notify user",
                action: Action.notify("Response copied to clipboard")
            )
        ]
    }
}

// MARK: - Screen Context

/// Context about what's on screen
struct ScreenContext {
    /// Description of what's visible
    let description: String

    /// Any selected/highlighted text
    let selectedText: String?

    /// Detected application
    let appName: String?

    /// Detected content type (code, text, image, etc.)
    let contentType: String?

    /// Additional context from Gemini analysis
    let analysisContext: String?

    init(
        description: String,
        selectedText: String? = nil,
        appName: String? = nil,
        contentType: String? = nil,
        analysisContext: String? = nil
    ) {
        self.description = description
        self.selectedText = selectedText
        self.appName = appName
        self.contentType = contentType
        self.analysisContext = analysisContext
    }

    /// Create from ProactiveSuggestionsResponse context
    static func from(context: String) -> ScreenContext {
        ScreenContext(
            description: context,
            analysisContext: context
        )
    }
}

// MARK: - Quick Actions

extension ActionPlanner {
    /// Quick action: Copy to clipboard
    func quickCopy(_ text: String) async throws {
        try await executeAction(Action.copy(text))
    }

    /// Quick action: Open URL
    func quickOpenUrl(_ url: String) async throws {
        try await executeAction(Action.openUrl(url))
    }

    /// Quick action: Google search
    func quickSearch(_ query: String) async throws {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        try await executeAction(Action.openUrl("https://www.google.com/search?q=\(encoded)"))
    }

    /// Quick action: Show notification
    func quickNotify(_ message: String, title: String = "IRIS") async throws {
        try await executeAction(Action.notify(message, title: title))
    }
}
