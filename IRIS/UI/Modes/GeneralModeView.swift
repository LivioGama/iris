import SwiftUI
import IRISCore

/// General Mode View - Flexible adaptive layout
/// Displays content in a minimal, open-ended structure
struct GeneralModeView: View {
    let parsedResponse: ICOIParsedResponse
    let config: ModeVisualConfig
    let screenshot: NSImage?
    @Binding var selectedOption: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: IRISSpacing.lg) {
            // Mode badge (minimal for general mode)
            modeBadge
                .padding(.horizontal, IRISSpacing.lg)
                .padding(.top, IRISSpacing.lg)

            // Flexible content area
            ScrollView {
                VStack(alignment: .leading, spacing: IRISSpacing.md) {
                    // Show screenshot if referenced
                    if let screenshot = screenshot {
                        screenshotPreview(screenshot)
                            .padding(.horizontal, IRISSpacing.lg)
                    }

                    // Render all parsed elements
                    ForEach(Array(parsedResponse.elements.enumerated()), id: \.offset) { _, element in
                        renderElement(element)
                            .padding(.horizontal, IRISSpacing.lg)
                    }
                }
                .frame(maxWidth: 680)
            }
            .padding(.bottom, IRISSpacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(config.backgroundColor)
    }

    // MARK: - Subviews

    private var modeBadge: some View {
        HStack(spacing: IRISSpacing.xs) {
            Text(config.icon)
                .font(.system(size: 14))

            Text(config.displayName)
                .irisStyle(.caption)
                .foregroundColor(IRISColors.textSecondary)
        }
        .padding(.horizontal, IRISSpacing.sm)
        .padding(.vertical, IRISSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.tight)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func screenshotPreview(_ screenshot: NSImage) -> some View {
        Image(nsImage: screenshot)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: IRISRadius.normal))
            .overlay(
                RoundedRectangle(cornerRadius: IRISRadius.normal)
                    .stroke(IRISColors.stroke, lineWidth: 1)
            )
            .opacity(0.4)
    }

    @ViewBuilder
    private func renderElement(_ element: ICOIResponseElement) -> some View {
        switch element {
        case .heading(let level, let text):
            Text(text)
                .irisStyle(level == 1 ? .hero : .title)
                .foregroundColor(IRISColors.textPrimary)
                .padding(.top, level == 1 ? IRISSpacing.md : IRISSpacing.xs)

        case .paragraph(let text):
            Text(text)
                .irisStyle(.body)
                .foregroundColor(IRISColors.textSecondary)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: IRISSpacing.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: IRISSpacing.xs) {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(config.accentColor)
                            .padding(.top, 3)

                        Text(item)
                            .irisStyle(.body)
                            .foregroundColor(IRISColors.textSecondary)
                    }
                }
            }

        case .numberedOption(let number, let title, let content):
            optionCard(number: number, title: title, content: content)

        case .codeBlock(let language, let code):
            codeBlockView(language: language, code: code)

        case .actionItem(let text, let assignee, let completed):
            actionItemView(text: text, assignee: assignee, completed: completed)
        }
    }

    private func optionCard(number: Int, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.xs) {
            HStack(spacing: IRISSpacing.xs) {
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(config.accentColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(config.accentColor.opacity(0.2))
                    )

                Text(title)
                    .irisStyle(.title)
                    .foregroundColor(IRISColors.textPrimary)
            }

            Text(content)
                .irisStyle(.body)
                .foregroundColor(IRISColors.textSecondary)
                .padding(.leading, 32)
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func codeBlockView(language: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label
            HStack {
                Text(language.uppercased())
                    .font(IRISTypography.badge)
                    .tracking(IRISTypography.badgeTracking)
                    .foregroundColor(IRISColors.textSecondary)
                    .padding(.horizontal, IRISSpacing.xs)
                    .padding(.vertical, IRISSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )

                Spacer()

                Button(action: { copyToClipboard(code) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("Copy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(IRISColors.textSecondary)
                    .padding(.horizontal, IRISSpacing.xs)
                    .padding(.vertical, IRISSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, IRISSpacing.sm)
            .padding(.vertical, IRISSpacing.xs)
            .background(Color.black.opacity(0.2))

            // Code content
            ScrollView(.horizontal) {
                Text(code)
                    .font(IRISTypography.codeStyle())
                    .foregroundColor(IRISColors.textPrimary)
                    .textSelection(.enabled)
                    .padding(IRISSpacing.sm)
            }
            .frame(maxHeight: 300)
        }
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.3))
        )
    }

    private func actionItemView(text: String, assignee: String?, completed: Bool) -> some View {
        HStack(alignment: .top, spacing: IRISSpacing.xs) {
            Text(completed ? "✅" : "⏳")
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .irisStyle(.body)
                    .foregroundColor(IRISColors.textPrimary)
                    .strikethrough(completed, color: IRISColors.textDimmed)

                if let assignee = assignee {
                    Text("→ \(assignee)")
                        .irisStyle(.caption)
                        .foregroundColor(IRISColors.textTertiary)
                }
            }
        }
        .padding(IRISSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.2))
        )
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
