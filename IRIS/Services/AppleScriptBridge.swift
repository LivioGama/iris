//
//  AppleScriptBridge.swift
//  IRIS
//
//  Bridge to macOS automation via AppleScript and System Events
//

import Foundation
import AppKit
import Carbon.HIToolbox

/// Bridge to macOS automation capabilities
/// Requires Accessibility permission for most operations
class AppleScriptBridge {
    /// Singleton instance
    static let shared = AppleScriptBridge()

    /// Whether Accessibility permission is granted
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    private init() {}

    // MARK: - App Control

    /// Activate (bring to front) an app by name or bundle ID
    func activateApp(_ nameOrBundleId: String) async throws {
        // Try by name first
        let script = """
        tell application "\(nameOrBundleId)"
            activate
        end tell
        """

        try await runAppleScript(script)
    }

    /// Quit an app by name
    func quitApp(_ appName: String) async throws {
        let script = """
        tell application "\(appName)"
            quit
        end tell
        """

        try await runAppleScript(script)
    }

    /// Get the frontmost application name
    func getFrontmostApp() async throws -> String? {
        let script = """
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
            return frontApp
        end tell
        """

        return try await runAppleScript(script)
    }

    /// Check if an app is running
    func isAppRunning(_ appName: String) async throws -> Bool {
        let script = """
        tell application "System Events"
            return (name of processes) contains "\(appName)"
        end tell
        """

        let result = try await runAppleScript(script)
        return result?.lowercased() == "true"
    }

    // MARK: - Text Input

    /// Type text into the active application
    func typeText(_ text: String) async throws {
        // Escape special characters for AppleScript
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "System Events"
            keystroke "\(escaped)"
        end tell
        """

        try await runAppleScript(script)
    }

    /// Type text slowly (character by character with delay)
    func typeTextSlowly(_ text: String, delayMs: Int = 50) async throws {
        for char in text {
            let escaped = String(char)
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")

            let script = """
            tell application "System Events"
                keystroke "\(escaped)"
            end tell
            """

            try await runAppleScript(script)
            try await Task.sleep(nanoseconds: UInt64(delayMs * 1_000_000))
        }
    }

    /// Simulate a keystroke with modifiers
    func simulateKeystroke(_ key: String, modifiers: [String] = []) async throws {
        var modifierClause = ""
        if !modifiers.isEmpty {
            let modifierList = modifiers.map { modifier -> String in
                switch modifier.lowercased() {
                case "command", "cmd":
                    return "command down"
                case "shift":
                    return "shift down"
                case "option", "alt":
                    return "option down"
                case "control", "ctrl":
                    return "control down"
                default:
                    return "\(modifier) down"
                }
            }.joined(separator: ", ")
            modifierClause = " using {\(modifierList)}"
        }

        let script = """
        tell application "System Events"
            keystroke "\(key)"\(modifierClause)
        end tell
        """

        try await runAppleScript(script)
    }

    /// Press a key code (for special keys like Return, Tab, etc.)
    func pressKeyCode(_ keyCode: Int, modifiers: [String] = []) async throws {
        var modifierClause = ""
        if !modifiers.isEmpty {
            let modifierList = modifiers.map { modifier -> String in
                switch modifier.lowercased() {
                case "command", "cmd":
                    return "command down"
                case "shift":
                    return "shift down"
                case "option", "alt":
                    return "option down"
                case "control", "ctrl":
                    return "control down"
                default:
                    return "\(modifier) down"
                }
            }.joined(separator: ", ")
            modifierClause = " using {\(modifierList)}"
        }

        let script = """
        tell application "System Events"
            key code \(keyCode)\(modifierClause)
        end tell
        """

        try await runAppleScript(script)
    }

    // MARK: - Mouse Control

    /// Click at a specific position
    func click(at point: CGPoint) async throws {
        let script = """
        tell application "System Events"
            click at {\(Int(point.x)), \(Int(point.y))}
        end tell
        """

        try await runAppleScript(script)
    }

    /// Double-click at a specific position
    func doubleClick(at point: CGPoint) async throws {
        let script = """
        tell application "System Events"
            click at {\(Int(point.x)), \(Int(point.y))}
            delay 0.1
            click at {\(Int(point.x)), \(Int(point.y))}
        end tell
        """

        try await runAppleScript(script)
    }

    /// Right-click at a specific position
    func rightClick(at point: CGPoint) async throws {
        // Use CGEvent for right-click as AppleScript doesn't support it directly
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown,
                                mouseCursorPosition: point, mouseButton: .right)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
                              mouseCursorPosition: point, mouseButton: .right)

        mouseDown?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        mouseUp?.post(tap: .cghidEventTap)
    }

    /// Move mouse to a position
    func moveMouse(to point: CGPoint) async throws {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }

    // MARK: - System Actions

    /// Show a notification
    func showNotification(title: String, message: String, sound: Bool = true) async throws {
        let soundClause = sound ? " sound name \"default\"" : ""
        let script = """
        display notification "\(message)" with title "\(title)"\(soundClause)
        """

        try await runAppleScript(script)
    }

    /// Open System Preferences/Settings to a specific pane
    func openSystemSettings(_ pane: String? = nil) async throws {
        if let pane = pane {
            let script = """
            tell application "System Preferences"
                activate
                set the current pane to pane id "\(pane)"
            end tell
            """
            try await runAppleScript(script)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
        }
    }

    /// Get current clipboard contents
    func getClipboard() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    /// Set clipboard contents
    func setClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Messaging Apps

    /// Send an iMessage
    func sendIMessage(to recipient: String, message: String) async throws {
        let escapedMessage = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "\(recipient)" of targetService
            send "\(escapedMessage)" to targetBuddy
        end tell
        """

        try await runAppleScript(script)
    }

    // MARK: - Calendar

    /// Create a calendar event
    func createCalendarEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil
    ) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy h:mm:ss a"

        let startString = dateFormatter.string(from: startDate)
        let endString = dateFormatter.string(from: endDate)

        var notesClause = ""
        if let notes = notes {
            let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\\\"")
            notesClause = """
                set description of newEvent to "\(escapedNotes)"
            """
        }

        let script = """
        tell application "Calendar"
            tell calendar "Calendar"
                set newEvent to make new event with properties {summary:"\(title)", start date:date "\(startString)", end date:date "\(endString)"}
                \(notesClause)
            end tell
        end tell
        """

        try await runAppleScript(script)
    }

    // MARK: - Email

    /// Create a new email draft in Mail
    func createEmailDraft(to: String, subject: String, body: String) async throws {
        let escapedSubject = subject.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(escapedSubject)", content:"\(escapedBody)", visible:true}
            tell newMessage
                make new to recipient at end of to recipients with properties {address:"\(to)"}
            end tell
            activate
        end tell
        """

        try await runAppleScript(script)
    }

    // MARK: - Finder

    /// Open Finder at a path
    func openFinderAt(_ path: String) async throws {
        let script = """
        tell application "Finder"
            activate
            open POSIX file "\(path)"
        end tell
        """

        try await runAppleScript(script)
    }

    /// Get the current Finder selection
    func getFinderSelection() async throws -> [String] {
        let script = """
        tell application "Finder"
            set selectedItems to selection
            set pathList to {}
            repeat with anItem in selectedItems
                set end of pathList to POSIX path of (anItem as alias)
            end repeat
            return pathList
        end tell
        """

        guard let result = try await runAppleScript(script) else {
            return []
        }

        // Parse the comma-separated list
        return result
            .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - AppleScript Execution

    /// Run an AppleScript and return the result
    @discardableResult
    func runAppleScript(_ script: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                guard let scriptObject = NSAppleScript(source: script) else {
                    continuation.resume(throwing: AppleScriptError.invalidScript)
                    return
                }

                let result = scriptObject.executeAndReturnError(&error)

                if let error = error {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: AppleScriptError.executionFailed(errorMessage))
                    return
                }

                continuation.resume(returning: result.stringValue)
            }
        }
    }
}

// MARK: - Key Codes

extension AppleScriptBridge {
    /// Common key codes for special keys
    enum KeyCode: Int {
        case returnKey = 36
        case tab = 48
        case space = 49
        case delete = 51
        case escape = 53
        case leftArrow = 123
        case rightArrow = 124
        case downArrow = 125
        case upArrow = 126
        case f1 = 122
        case f2 = 120
        case f3 = 99
        case f4 = 118
        case f5 = 96
        case f6 = 97
        case f7 = 98
        case f8 = 100
        case f9 = 101
        case f10 = 109
        case f11 = 103
        case f12 = 111
    }

    /// Press a special key
    func pressKey(_ key: KeyCode, modifiers: [String] = []) async throws {
        try await pressKeyCode(key.rawValue, modifiers: modifiers)
    }
}

// MARK: - Errors

enum AppleScriptError: LocalizedError {
    case invalidScript
    case executionFailed(String)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidScript:
            return "Invalid AppleScript"
        case .executionFailed(let message):
            return "AppleScript failed: \(message)"
        case .permissionDenied:
            return "Accessibility permission required"
        }
    }
}
