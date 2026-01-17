//
//  ClipboardActionService.swift
//  IRIS
//
//  Simple clipboard service wrapping ActionExecutor
//

import Foundation
import AppKit

/// Simple clipboard service for copy/paste operations
class ClipboardActionService {

    /// Copy text to clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("📋 Copied \(text.count) characters to clipboard")
    }

    /// Get text from clipboard
    func getClipboardContents() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    /// Clear clipboard
    func clearClipboard() {
        NSPasteboard.general.clearContents()
    }

    /// Copy option content to clipboard
    func copyOptionContent(_ content: String) {
        copyToClipboard(content)
        print("📋 Copied option content to clipboard")
    }

    /// Copy code block to clipboard
    func copyCodeBlock(language: String, code: String) {
        copyToClipboard(code)
        print("📋 Copied \(language) code block to clipboard")
    }

    /// Copy full response to clipboard
    func copyFullResponse(_ response: String) {
        copyToClipboard(response)
        print("📋 Copied full response to clipboard")
    }

    /// Export content to file
    func exportToFile(content: String, suggestedName: String = "iris_export", fileExtension: String = "txt") async throws {
        await MainActor.run {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "\(suggestedName).\(fileExtension)"

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    print("📄 Exported to file: \(url.path)")
                } catch {
                    print("❌ Failed to export: \(error)")
                }
            }
        }
    }
}
