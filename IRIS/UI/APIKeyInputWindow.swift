import AppKit
import IRISCore

class APIKeyInputWindow: NSObject {
    private var window: NSWindow?
    private var textField: NSTextField!
    private let onSave: (String) -> Bool
    private let onCancel: () -> Void

    init(onSave: @escaping (String) -> Bool, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        super.init()
    }

    func showWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "IRIS Setup - API Key Required"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating  // Ensure it's above everything
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Create content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 200))
        contentView.wantsLayer = true

        // Title label
        let titleLabel = NSTextField(labelWithString: "Gemini API Key Required")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: 140, width: 410, height: 24)
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        contentView.addSubview(titleLabel)

        // Info label
        let infoLabel = NSTextField(wrappingLabelWithString: "Enter your Gemini API key to enable AI features.\nGet your key from: https://aistudio.google.com/apikey")
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoLabel.frame = NSRect(x: 20, y: 90, width: 410, height: 40)
        infoLabel.isBezeled = false
        infoLabel.drawsBackground = false
        infoLabel.isEditable = false
        infoLabel.isSelectable = false
        contentView.addSubview(infoLabel)

        // Text field - EDITABLE
        textField = NSTextField(frame: NSRect(x: 20, y: 50, width: 410, height: 24))
        textField.placeholderString = "AIza..."
        textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textField.isBezeled = true
        textField.isEditable = true
        textField.isSelectable = true
        textField.focusRingType = .default
        textField.bezelStyle = .roundedBezel
        contentView.addSubview(textField)

        // Buttons
        let saveButton = NSButton(frame: NSRect(x: 350, y: 12, width: 80, height: 28))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        contentView.addSubview(saveButton)

        let cancelButton = NSButton(frame: NSRect(x: 260, y: 12, width: 80, height: 28))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        contentView.addSubview(cancelButton)

        window.contentView = contentView

        // Force the window to be key and active
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Delay to ensure window is ready, then set first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeFirstResponder(self.textField)
            print("🔑 Text field is first responder: \(window.firstResponder == self.textField)")
            print("🔑 Text field is editable: \(self.textField.isEditable)")
            print("🔑 Window is key: \(window.isKeyWindow)")
        }

        self.window = window
    }

    @objc private func saveClicked() {
        let apiKey = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if onSave(apiKey) {
            window?.close()
            window = nil
        }
    }

    @objc private func cancelClicked() {
        window?.close()
        window = nil
        onCancel()
    }
}
