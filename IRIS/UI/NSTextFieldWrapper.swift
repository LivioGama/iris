import SwiftUI
import AppKit

/// A wrapper around NSTextField for proper keyboard input in macOS windows
struct NSTextFieldWrapper: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.isEnabled = isEnabled
        textField.isBordered = true
        textField.bezelStyle = .squareBezel
        textField.drawsBackground = true
        textField.backgroundColor = .textBackgroundColor
        textField.isEditable = true
        textField.isSelectable = true
        textField.allowsEditingTextAttributes = false
        textField.importsGraphics = false

        print("📝 NSTextField created - editable: \(textField.isEditable), selectable: \(textField.isSelectable)")

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NSTextFieldWrapper

        init(_ parent: NSTextFieldWrapper) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
                print("🔤 Text changed to: '\(textField.stringValue)' (length: \(textField.stringValue.count))")
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            print("📝 TextField began editing")
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            print("📝 TextField ended editing")
        }
    }
}
