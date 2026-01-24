import SwiftUI
import IRISCore
import AppKit

// MARK: - All Templates Showcase View

/// Displays all demo templates at once - compact, transparent liquid glass style
struct AllTemplatesShowcaseView: View {
    let onClose: () -> Void

    private let demoSchemas = DynamicUIDemoGenerator.allDemoSchemas()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        // Compact header pill
                        showcaseHeader

                        // 2-column grid
                        let columns = [
                            GridItem(.flexible(minimum: 400), spacing: 20),
                            GridItem(.flexible(minimum: 400), spacing: 20)
                        ]

                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(Array(demoSchemas.enumerated()), id: \.offset) { index, schema in
                                templateCard(schema: schema, index: index, availableWidth: (geometry.size.width - 60) / 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }

                // Minimal close button
                closeButton
            }
        }
        .background(showcaseBackground)
    }

    private var showcaseHeader: some View {
        HStack(spacing: 10) {
            // Glowing dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan, Color.cyan.opacity(0.4)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 5
                    )
                )
                .frame(width: 10, height: 10)
                .shadow(color: Color.cyan.opacity(0.6), radius: 6, x: 0, y: 0)

            Text("TEMPLATES")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.9), .white.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .tracking(1.5)

            Text("·")
                .foregroundColor(.white.opacity(0.3))

            Text("\(demoSchemas.count)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.top, 16)
    }

    private func templateCard(schema: DynamicUISchema, index: Int, availableWidth: CGFloat) -> some View {
        let accentColor = Color(hex: schema.theme.accentColor)

        return VStack(alignment: .leading, spacing: 0) {
            // Minimal header - icon + title inline
            HStack(spacing: 8) {
                Text(schema.theme.icon ?? "📄")
                    .font(.system(size: 16))

                Text(schema.theme.title ?? "Template")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer()

                // Accent dot
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: accentColor.opacity(0.5), radius: 4, x: 0, y: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Template content - full width
            DynamicUIRenderer(
                schema: schema,
                screenshot: nil,
                onAction: nil
            )
            .frame(width: availableWidth, height: 350)
            .clipped()
        }
        .frame(width: availableWidth)
        .background(templateCardBackground(accentColor: accentColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func templateCardBackground(accentColor: Color) -> some View {
        ZStack {
            // Glass blur for readability
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .opacity(0.85)

            // Accent tint
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accentColor.opacity(0.05))

            // Border
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(8)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(12)
    }

    private var showcaseBackground: some View {
        // Fully transparent
        Color.clear
    }
}

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
