import SwiftUI
import IRISCore

/// Code Improvement Mode View - Split-pane analytical layout
/// Displays before/after code comparison with diff highlighting
struct CodeImprovementModeView: View {
    let parsedResponse: ICOIParsedResponse
    let config: ModeVisualConfig
    @Binding var selectedOption: Int?

    @State private var hoveredPane: CodePane? = nil
    @State private var showImprovements = true

    enum CodePane {
        case before
        case after
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with mode badge
            modeBadge
                .padding(.horizontal, IRISSpacing.lg)
                .padding(.top, IRISSpacing.lg)
                .padding(.bottom, IRISSpacing.md)

            // Key improvements section (collapsible)
            if !parsedResponse.improvements.isEmpty {
                improvementsSection
                    .padding(.horizontal, IRISSpacing.lg)
                    .padding(.bottom, IRISSpacing.md)
            }

            // Split-pane code comparison
            HStack(alignment: .top, spacing: IRISSpacing.md) {
                // Before code pane
                codePane(
                    title: "BEFORE",
                    code: parsedResponse.oldCode ?? "",
                    isAfter: false,
                    paneType: .before
                )

                // Arrow separator
                arrowSeparator

                // After code pane
                codePane(
                    title: "AFTER",
                    code: parsedResponse.newCode ?? "",
                    isAfter: true,
                    paneType: .after
                )
            }
            .padding(.horizontal, IRISSpacing.lg)
            .padding(.bottom, IRISSpacing.lg)
        }
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

    private var improvementsSection: some View {
        VStack(alignment: .leading, spacing: IRISSpacing.xs) {
            Button(action: { withAnimation { showImprovements.toggle() }}) {
                HStack(spacing: IRISSpacing.xs) {
                    Image(systemName: showImprovements ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(config.accentColor)

                    Text("Key Improvements")
                        .irisStyle(.title)
                        .foregroundColor(IRISColors.textPrimary)
                }
            }
            .buttonStyle(.plain)

            if showImprovements {
                VStack(alignment: .leading, spacing: IRISSpacing.xxs) {
                    ForEach(Array(parsedResponse.improvements.enumerated()), id: \.offset) { _, improvement in
                        HStack(alignment: .top, spacing: IRISSpacing.xs) {
                            Text("◆")
                                .font(.system(size: 10))
                                .foregroundColor(config.accentColor)
                                .padding(.top, 3)

                            Text(improvement)
                                .irisStyle(.body)
                                .foregroundColor(IRISColors.textSecondary)
                        }
                    }
                }
                .padding(.top, IRISSpacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(config.accentColor.opacity(0.08))
        )
    }

    private func codePane(title: String, code: String, isAfter: Bool, paneType: CodePane) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pane header
            HStack {
                Text(title)
                    .font(IRISTypography.badge)
                    .tracking(IRISTypography.badgeTracking)
                    .foregroundColor(isAfter ? IRISColors.success : IRISColors.error)
                    .padding(.horizontal, IRISSpacing.xs)
                    .padding(.vertical, IRISSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill((isAfter ? IRISColors.success : IRISColors.error).opacity(0.15))
                    )

                Spacer()

                // Copy button (only on AFTER pane)
                if isAfter {
                    Button(action: { copyToClipboard(code) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                            Text("Copy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(IRISColors.textSecondary)
                        .padding(.horizontal, IRISSpacing.xs)
                        .padding(.vertical, IRISSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(IRISColors.success.opacity(0.2))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, IRISSpacing.sm)
            .padding(.vertical, IRISSpacing.xs)
            .background(Color.black.opacity(0.2))

            // Code content
            ScrollView([.vertical, .horizontal]) {
                Text(code)
                    .font(IRISTypography.codeStyle())
                    .foregroundColor(isAfter ? IRISColors.textPrimary : IRISColors.textSecondary)
                    .textSelection(.enabled)
                    .padding(IRISSpacing.sm)
                    .lineSpacing(2)
            }
            .frame(maxHeight: 500)
        }
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(hoveredPane == paneType ? 0.4 : 0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .stroke(
                    isAfter ? IRISColors.diffAddedBorder : IRISColors.diffRemovedBorder,
                    lineWidth: hoveredPane == paneType ? 1.5 : 1
                )
                .opacity(0.3)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredPane = hovering ? paneType : nil
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var arrowSeparator: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(config.accentColor.opacity(0.6))
            Spacer()
        }
        .frame(width: 40)
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
