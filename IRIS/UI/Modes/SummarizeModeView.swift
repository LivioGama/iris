import SwiftUI
import IRISCore

/// Summarize Mode View - Vertical editorial layout
/// Displays structured summary with overview, key points, and insights
struct SummarizeModeView: View {
    let parsedResponse: ICOIParsedResponse
    let config: ModeVisualConfig
    let screenshot: NSImage?
    @Binding var selectedOption: Int?

    @State private var expandedSections: Set<String> = ["overview", "keypoints", "insights"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width screenshot header (dimmed)
            if let screenshot = screenshot {
                screenshotHeader(screenshot)
            }

            // Mode badge
            modeBadge
                .padding(.horizontal, IRISSpacing.lg)
                .padding(.top, IRISSpacing.lg)
                .padding(.bottom, IRISSpacing.md)

            // Content sections
            ScrollView {
                VStack(alignment: .leading, spacing: IRISSpacing.lg) {
                    ForEach(Array(parsedResponse.elements.enumerated()), id: \.offset) { index, element in
                        renderElement(element, index: index)
                    }
                }
                .padding(.horizontal, IRISSpacing.lg)
                .padding(.bottom, IRISSpacing.lg)
                .frame(maxWidth: 680)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(config.backgroundColor)
    }

    // MARK: - Subviews

    private func screenshotHeader(_ screenshot: NSImage) -> some View {
        Image(nsImage: screenshot)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [Color.clear, config.backgroundColor.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(0.5)
    }

    private var modeBadge: some View {
        HStack(spacing: IRISSpacing.xs) {
            Text(config.icon)
                .font(.system(size: 16))

            Text(config.displayName)
                .irisStyle(.caption)
                .foregroundColor(IRISColors.textPrimary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, IRISSpacing.sm)
        .padding(.vertical, IRISSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.tight)
                .fill(config.accentGradient.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IRISRadius.tight)
                .stroke(config.accentColor.opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func renderElement(_ element: ICOIResponseElement, index: Int) -> some View {
        switch element {
        case .heading(let level, let text):
            sectionHeading(text, level: level)
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .paragraph(let text):
            Text(text)
                .irisStyle(.body)
                .foregroundColor(IRISColors.textSecondary)
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .bulletList(let items):
            bulletListView(items: items)
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .actionItem(let text, let assignee, let completed):
            actionItemView(text: text, assignee: assignee, completed: completed)
                .transition(.opacity.combined(with: .move(edge: .top)))

        case .codeBlock(let language, let code):
            codeBlockView(language: language, code: code)
                .transition(.opacity.combined(with: .move(edge: .top)))

        default:
            EmptyView()
        }
    }

    private func sectionHeading(_ text: String, level: Int) -> some View {
        HStack(spacing: IRISSpacing.xs) {
            Text("◆")
                .font(.system(size: level == 1 ? 16 : 14))
                .foregroundColor(config.accentColor)

            Text(text.uppercased())
                .irisStyle(level == 1 ? .title : .body)
                .foregroundColor(IRISColors.textPrimary)
                .fontWeight(level == 1 ? .semibold : .medium)
        }
        .padding(.top, level == 1 ? IRISSpacing.md : IRISSpacing.xs)
    }

    private func bulletListView(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.xs) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: IRISSpacing.xs) {
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(config.accentColor.opacity(0.8))
                        .padding(.top, 3)

                    Text(item)
                        .irisStyle(.body)
                        .foregroundColor(IRISColors.textSecondary)
                }
            }
        }
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
                    Text("Assigned to: \(assignee)")
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
        }
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.3))
        )
    }
}
