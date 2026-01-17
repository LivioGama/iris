//
//  ActionExecutor.swift
//  IRIS
//
//  Executes actions from skills - the "hands" of IRIS
//

import Foundation
import AppKit
import IRISCore

/// Executes actions from skills
/// This is the layer that actually performs operations
class ActionExecutor {
    /// Singleton instance
    static let shared = ActionExecutor()

    /// AppleScript bridge for app control
    private let appleScriptBridge = AppleScriptBridge.shared

    /// Whether execution is currently in progress
    private(set) var isExecuting = false

    /// Callback for execution progress
    var onProgress: ((String) -> Void)?

    /// Callback for execution completion
    var onComplete: ((ActionResult) -> Void)?

    private init() {}

    // MARK: - Public API

    /// Execute a single action
    @discardableResult
    func execute(_ action: Action) async throws -> ActionResult {
        isExecuting = true
        defer { isExecuting = false }

        onProgress?("Executing: \(action.description)")

        do {
            let output = try await performAction(action)
            let result = ActionResult.success(action, output: output)
            onComplete?(result)
            return result
        } catch {
            let result = ActionResult.failure(action, error: error.localizedDescription)
            onComplete?(result)
            throw error
        }
    }

    /// Execute multiple actions in sequence
    func executeAll(_ actions: [Action]) async throws -> [ActionResult] {
        var results: [ActionResult] = []

        for action in actions {
            do {
                let result = try await execute(action)
                results.append(result)

                // Stop on first failure if action requires confirmation
                if !result.success && action.requiresConfirmation {
                    break
                }
            } catch {
                results.append(ActionResult.failure(action, error: error.localizedDescription))
                break
            }
        }

        return results
    }

    /// Execute an action plan
    func execute(_ plan: ActionPlan) async throws -> ExecutionResult {
        let startTime = Date()
        var results: [ActionResult] = []
        var overallSuccess = true

        for step in plan.steps {
            onProgress?("Step: \(step.description)")

            do {
                let result = try await execute(step.action)
                results.append(result)

                if !result.success {
                    // Try fallback if available
                    if let fallback = step.fallbackAction {
                        onProgress?("Trying fallback: \(fallback.description)")
                        let fallbackResult = try await execute(fallback)
                        results.append(fallbackResult)
                        if !fallbackResult.success {
                            overallSuccess = false
                            break
                        }
                    } else {
                        overallSuccess = false
                        break
                    }
                }
            } catch {
                results.append(ActionResult.failure(step.action, error: error.localizedDescription))
                overallSuccess = false
                break
            }
        }

        return ExecutionResult(
            plan: plan,
            results: results,
            overallSuccess: overallSuccess,
            startTime: startTime,
            endTime: Date()
        )
    }

    // MARK: - Action Implementations

    private func performAction(_ action: Action) async throws -> String? {
        switch action.type {
        case .copy:
            return try performCopy(action)

        case .paste:
            return try await performPaste(action)

        case .typeText:
            return try await performTypeText(action)

        case .click:
            return try await performClick(action)

        case .pressKey:
            return try await performPressKey(action)

        case .openUrl:
            return try performOpenUrl(action)

        case .openApp:
            return try performOpenApp(action)

        case .activateApp:
            return try await performActivateApp(action)

        case .runCommand:
            return try await performRunCommand(action)

        case .runScript:
            return try await performRunScript(action)

        case .readFile:
            return try performReadFile(action)

        case .writeFile:
            return try performWriteFile(action)

        case .createFile:
            return try performCreateFile(action)

        case .httpRequest:
            return try await performHttpRequest(action)

        case .notify:
            return try performNotify(action)

        case .speak:
            return try await performSpeak(action)
            
        case .scroll:
            return try await performScroll(action)
        }
    }

    // MARK: - Clipboard Actions

    private func performCopy(_ action: Action) throws -> String? {
        guard let text = action.parameters["text"] else {
            throw ActionError.missingParameter("text")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        print("📋 Copied \(text.count) characters to clipboard")
        return "Copied to clipboard"
    }

    private func performPaste(_ action: Action) async throws -> String? {
        // Simulate Cmd+V
        try await appleScriptBridge.simulateKeystroke("v", modifiers: ["command"])
        return "Pasted from clipboard"
    }

    // MARK: - Input Actions

    private func performTypeText(_ action: Action) async throws -> String? {
        guard let text = action.parameters["text"] else {
            throw ActionError.missingParameter("text")
        }

        // Optionally activate an app first
        if let appName = action.parameters["app"] {
            try await appleScriptBridge.activateApp(appName)
            // Small delay to ensure app is focused
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }

        try await appleScriptBridge.typeText(text)
        return "Typed \(text.count) characters"
    }

    private func performClick(_ action: Action) async throws -> String? {
        guard let xStr = action.parameters["x"],
              let yStr = action.parameters["y"],
              let x = Double(xStr),
              let y = Double(yStr) else {
            throw ActionError.missingParameter("x, y coordinates")
        }

        try await appleScriptBridge.click(at: CGPoint(x: x, y: y))
        return "Clicked at (\(x), \(y))"
    }

    private func performPressKey(_ action: Action) async throws -> String? {
        guard let key = action.parameters["key"] else {
            throw ActionError.missingParameter("key")
        }

        let modifiers = action.parameters["modifiers"]?.split(separator: ",").map(String.init) ?? []
        try await appleScriptBridge.simulateKeystroke(key, modifiers: modifiers)
        return "Pressed \(modifiers.joined(separator: "+"))\(modifiers.isEmpty ? "" : "+")\(key)"
    }

    // MARK: - App Actions

    private func performOpenUrl(_ action: Action) throws -> String? {
        guard let urlString = action.parameters["url"],
              let url = URL(string: urlString) else {
            throw ActionError.missingParameter("url")
        }

        NSWorkspace.shared.open(url)
        print("🌐 Opened URL: \(urlString)")
        return "Opened \(urlString)"
    }

    private func performOpenApp(_ action: Action) throws -> String? {
        guard let bundleId = action.parameters["bundle_id"] else {
            throw ActionError.missingParameter("bundle_id")
        }

        guard let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            throw ActionError.appNotFound(bundleId)
        }

        NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration())
        print("🚀 Opened app: \(bundleId)")
        return "Opened app"
    }

    private func performActivateApp(_ action: Action) async throws -> String? {
        guard let appName = action.parameters["app"] ?? action.parameters["bundle_id"] else {
            throw ActionError.missingParameter("app or bundle_id")
        }

        try await appleScriptBridge.activateApp(appName)
        return "Activated \(appName)"
    }

    // MARK: - Shell Actions

    private func performRunCommand(_ action: Action) async throws -> String? {
        guard let command = action.parameters["command"] else {
            throw ActionError.missingParameter("command")
        }

        print("🖥️ Running command: \(command)")

        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw ActionError.commandFailed(command, output)
        }

        print("✅ Command completed: \(output.prefix(100))")
        return output
    }

    private func performRunScript(_ action: Action) async throws -> String? {
        guard let script = action.parameters["script"] else {
            throw ActionError.missingParameter("script")
        }

        // Write script to temp file and execute
        let tempPath = "/tmp/iris_script_\(UUID().uuidString).sh"
        try script.write(toFile: tempPath, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(atPath: tempPath)
        }

        // Make executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempPath)

        // Run
        let runAction = Action(
            type: .runCommand,
            parameters: ["command": tempPath],
            description: "Run script"
        )
        return try await performRunCommand(runAction)
    }

    // MARK: - File Actions

    private func performReadFile(_ action: Action) throws -> String? {
        guard let path = action.parameters["path"] else {
            throw ActionError.missingParameter("path")
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
        return content
    }

    private func performWriteFile(_ action: Action) throws -> String? {
        guard let path = action.parameters["path"],
              let content = action.parameters["content"] else {
            throw ActionError.missingParameter("path and content")
        }

        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return "Wrote \(content.count) characters to \(path)"
    }

    private func performCreateFile(_ action: Action) throws -> String? {
        guard let path = action.parameters["path"] else {
            throw ActionError.missingParameter("path")
        }

        let content = action.parameters["content"] ?? ""

        // Create parent directories if needed
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return "Created file: \(path)"
    }

    // MARK: - API Actions

    private func performHttpRequest(_ action: Action) async throws -> String? {
        guard let urlString = action.parameters["url"],
              let url = URL(string: urlString) else {
            throw ActionError.missingParameter("url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = action.parameters["method"] ?? "GET"

        if let body = action.parameters["body"] {
            request.httpBody = body.data(using: .utf8)
        }

        if let contentType = action.parameters["content_type"] {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ActionError.httpRequestFailed(urlString)
        }

        return String(data: data, encoding: .utf8)
    }

    // MARK: - System Actions

    private func performNotify(_ action: Action) throws -> String? {
        guard let message = action.parameters["message"] else {
            throw ActionError.missingParameter("message")
        }

        let title = action.parameters["title"] ?? "IRIS"

        // Use AppleScript to show notification
        let script = """
        display notification "\(message)" with title "\(title)"
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }

        if let error = error {
            throw ActionError.appleScriptFailed(error.description)
        }

        return "Notification shown"
    }

    private func performSpeak(_ action: Action) async throws -> String? {
        guard let text = action.parameters["text"] else {
            throw ActionError.missingParameter("text")
        }

        let synthesizer = NSSpeechSynthesizer()
        synthesizer.startSpeaking(text)

        // Wait for speech to complete
        while synthesizer.isSpeaking {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        return "Spoke: \(text.prefix(50))"
    }

    private func performScroll(_ action: Action) async throws -> String? {
        let direction = action.parameters["direction"] ?? "down"
        let amount = Int(action.parameters["amount"] ?? "5") ?? 5
        
        try await appleScriptBridge.scroll(direction: direction, amount: amount)
        return "Scrolled \(direction) by \(amount)"
    }
}

// MARK: - Action Errors

enum ActionError: LocalizedError {
    case missingParameter(String)
    case appNotFound(String)
    case commandFailed(String, String)
    case appleScriptFailed(String)
    case httpRequestFailed(String)
    case executionCancelled

    var errorDescription: String? {
        switch self {
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .appNotFound(let bundleId):
            return "App not found: \(bundleId)"
        case .commandFailed(let command, let output):
            return "Command failed: \(command)\nOutput: \(output)"
        case .appleScriptFailed(let error):
            return "AppleScript failed: \(error)"
        case .httpRequestFailed(let url):
            return "HTTP request failed: \(url)"
        case .executionCancelled:
            return "Execution was cancelled"
        }
    }
}

// MARK: - Convenience Extensions

extension ActionExecutor {
    /// Quick copy to clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Quick open URL
    func openUrl(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Quick Google search
    func googleSearch(_ query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        openUrl("https://www.google.com/search?q=\(encoded)")
    }
}
