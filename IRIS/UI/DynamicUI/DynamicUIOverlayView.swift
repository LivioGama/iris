import SwiftUI
import IRISCore
import AppKit

/// A view that displays the AI-generated dynamic UI
/// This integrates with the existing overlay system
struct DynamicUIOverlayView: View {
    let schema: DynamicUISchema
    let screenshot: NSImage?
    let onClose: () -> Void
    let onAction: ((UIAction) -> Void)?

    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main dynamic UI content
            DynamicUIRenderer(
                schema: schema,
                screenshot: screenshot,
                onAction: { action in
                    handleAction(action)
                }
            )
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.95)

            // Close button
            Button(action: onClose) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 32, height: 32)

                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(IRISSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.relaxed)
                .fill(Color.black.opacity(0.85))
                .shadow(color: Color(hex: schema.theme.accentColor).opacity(0.3), radius: 20)
        )
        .clipShape(RoundedRectangle(cornerRadius: IRISRadius.relaxed))
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    private func handleAction(_ action: UIAction) {
        switch action.type {
        case .copy:
            if let payload = action.payload {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(payload, forType: .string)
            }
        case .dismiss:
            onClose()
        case .speak:
            // TTS could be implemented here
            if let payload = action.payload {
                print("🔊 TTS requested: \(payload)")
            }
        default:
            // Pass other actions to the parent handler
            onAction?(action)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct DynamicUIOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSchema = DynamicUISchema(
            layout: UILayout(
                direction: .vertical,
                spacing: .lg,
                maxWidth: 700,
                padding: .lg,
                alignment: .leading
            ),
            theme: UITheme(
                accentColor: "#0066FF",
                secondaryColor: "#00D4FF",
                background: .darker,
                mood: .analytical,
                icon: "💻",
                title: "Code Review"
            ),
            components: [
                .heading(HeadingComponent(text: "Code Improvements", level: 1, icon: "✨")),
                .paragraph(ParagraphComponent(text: "Here are some suggested improvements for your code:", style: .body)),
                .bulletList(BulletListComponent(items: [
                    "Use descriptive variable names",
                    "Add error handling",
                    "Extract repeated logic into functions"
                ], bulletStyle: .check)),
                .codeBlock(CodeBlockComponent(
                    code: "function calculate(x) {\n  return x * 2;\n}",
                    language: "javascript",
                    copyable: true
                ))
            ],
            screenshotConfig: ScreenshotDisplayConfig(visible: false, position: .hidden, size: .small, opacity: 0.8)
        )

        DynamicUIOverlayView(
            schema: sampleSchema,
            screenshot: nil,
            onClose: {},
            onAction: nil
        )
        .frame(width: 800, height: 600)
        .background(Color.gray.opacity(0.3))
    }
}
#endif
