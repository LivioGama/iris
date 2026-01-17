import AppKit

class APIKeyTextFieldDelegate: NSObject, NSTextFieldDelegate {
    weak var saveButton: NSButton?

    func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else { return }

        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValid = !text.isEmpty && text.hasPrefix("AIza") && text.count >= 30

        print("🔑 Text changed via delegate: '\(text.prefix(10))...' length:\(text.count) valid:\(isValid)")
        saveButton?.isEnabled = isValid
    }
}
