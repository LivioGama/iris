import SwiftUI
import IRISCore

/// Tone Feedback Mode View - Dual-panel critical layout
/// Displays original text with tone analysis and rewrite suggestions
struct ToneFeedbackModeView: View {
    let parsedResponse: ICOIParsedResponse
    let config: ModeVisualConfig
    let screenshot: NSImage?
    @Binding var selectedOption: Int?

    @State private var selectedRewrite: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with mode badge
            modeBadge
                .padding(.horizontal, IRISSpacing.lg)
                .padding(.top, IRISSpacing.lg)
                .padding(.bottom, IRISSpacing.md)

            // Dual-panel layout
            HStack(alignment: .top, spacing: IRISSpacing.md) {
                // Left: Original text with annotations
                originalTextPanel

                // Right: Analysis and metrics
                analysisPanel
            }
            .padding(.horizontal, IRISSpacing.lg)

            // Bottom: Rewrite suggestions
            if parsedResponse.hasOptions {
                rewriteSuggestionsSection
                    .padding(.horizontal, IRISSpacing.lg)
                    .padding(.top, IRISSpacing.md)
            }

            Spacer()
        }
        .padding(.bottom, IRISSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(config.backgroundColor)
    }

    // MARK: - Subviews

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

    private var originalTextPanel: some View {
        VStack(alignment: .leading, spacing: IRISSpacing.sm) {
            Text("ORIGINAL TEXT")
                .font(IRISTypography.badge)
                .tracking(IRISTypography.badgeTracking)
                .foregroundColor(IRISColors.textSecondary)

            // Show screenshot if available, otherwise show extracted text
            if let screenshot = screenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: IRISRadius.normal))
                    .overlay(
                        RoundedRectangle(cornerRadius: IRISRadius.normal)
                            .stroke(IRISColors.stroke, lineWidth: 1)
                    )
            } else {
                // Fallback to showing paragraphs from parsed response
                ScrollView {
                    VStack(alignment: .leading, spacing: IRISSpacing.xs) {
                        ForEach(Array(parsedResponse.elements.enumerated()), id: \.offset) { _, element in
                            if case .paragraph(let text) = element {
                                Text(text)
                                    .irisStyle(.body)
                                    .foregroundColor(IRISColors.textPrimary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(IRISSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.3))
        )
    }

    private var analysisPanel: some View {
        VStack(alignment: .leading, spacing: IRISSpacing.sm) {
            Text("ANALYSIS")
                .font(IRISTypography.badge)
                .tracking(IRISTypography.badgeTracking)
                .foregroundColor(config.accentColor)

            ScrollView {
                VStack(alignment: .leading, spacing: IRISSpacing.md) {
                    // Render analysis elements (headings, bullets, etc.)
                    ForEach(Array(parsedResponse.elements.enumerated()), id: \.offset) { _, element in
                        switch element {
                        case .heading(_, let text):
                            Text(text)
                                .irisStyle(.title)
                                .foregroundColor(IRISColors.textPrimary)
                                .padding(.top, IRISSpacing.xs)

                        case .bulletList(let items):
                            VStack(alignment: .leading, spacing: IRISSpacing.xxs) {
                                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .top, spacing: IRISSpacing.xs) {
                                        Text("•")
                                            .foregroundColor(config.accentColor)
                                        Text(item)
                                            .irisStyle(.body)
                                            .foregroundColor(IRISColors.textSecondary)
                                    }
                                }
                            }

                        case .paragraph(let text):
                            if !parsedResponse.hasOptions {  // Only show paragraphs if no options
                                Text(text)
                                    .irisStyle(.body)
                                    .foregroundColor(IRISColors.textSecondary)
                            }

                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(IRISSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .stroke(config.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var rewriteSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: IRISSpacing.sm) {
            Text("SUGGESTED REWRITES")
                .font(IRISTypography.badge)
                .tracking(IRISTypography.badgeTracking)
                .foregroundColor(IRISColors.textPrimary)

            // Tab selector
            if parsedResponse.numberedOptions.count > 1 {
                HStack(spacing: IRISSpacing.xs) {
                    ForEach(parsedResponse.numberedOptions, id: \.number) { option in
                        Button(action: { withAnimation { selectedRewrite = option.number } }) {
                            Text(option.title)
                                .irisStyle(.caption)
                                .foregroundColor(
                                    selectedRewrite == option.number || (selectedRewrite == nil && option.number == 1)
                                    ? IRISColors.textPrimary
                                    : IRISColors.textSecondary
                                )
                                .padding(.horizontal, IRISSpacing.sm)
                                .padding(.vertical, IRISSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: IRISRadius.tight)
                                        .fill(
                                            selectedRewrite == option.number || (selectedRewrite == nil && option.number == 1)
                                            ? config.accentColor.opacity(0.3)
                                            : Color.black.opacity(0.2)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Display selected rewrite
            if let selected = selectedRewrite ?? parsedResponse.numberedOptions.first?.number {
                if let option = parsedResponse.numberedOptions.first(where: { $0.number == selected }) {
                    HStack {
                        Text(option.content)
                            .irisStyle(.body)
                            .foregroundColor(IRISColors.textPrimary)
                            .textSelection(.enabled)
                            .padding(IRISSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: IRISRadius.normal)
                                    .fill(Color.black.opacity(0.3))
                            )

                        // Copy button
                        Button(action: { copyToClipboard(option.content) }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(IRISColors.textSecondary)
                                .padding(IRISSpacing.sm)
                                .background(
                                    Circle()
                                        .fill(config.accentColor.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
