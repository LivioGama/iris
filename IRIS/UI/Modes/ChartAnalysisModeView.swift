import SwiftUI
import IRISCore

/// Chart Analysis Mode View - Large canvas data-driven layout
/// Displays chart/screenshot prominently with insights sidebar
struct ChartAnalysisModeView: View {
    let parsedResponse: ICOIParsedResponse
    let config: ModeVisualConfig
    let screenshot: NSImage?
    @Binding var selectedOption: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with mode badge
            modeBadge
                .padding(.horizontal, IRISSpacing.lg)
                .padding(.top, IRISSpacing.lg)
                .padding(.bottom, IRISSpacing.md)

            // Main layout: Large chart + Sidebar
            HStack(alignment: .top, spacing: IRISSpacing.lg) {
                // Left: Large chart/screenshot
                if let screenshot = screenshot {
                    chartPanel(screenshot)
                        .frame(maxWidth: .infinity)
                }

                // Right: Insights sidebar
                insightsSidebar
                    .frame(width: 300)
            }
            .padding(.horizontal, IRISSpacing.lg)
            .padding(.bottom, IRISSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private func chartPanel(_ screenshot: NSImage) -> some View {
        VStack(spacing: 0) {
            Image(nsImage: screenshot)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 600)
                .clipShape(RoundedRectangle(cornerRadius: IRISRadius.normal))
                .overlay(
                    RoundedRectangle(cornerRadius: IRISRadius.normal)
                        .stroke(config.accentColor.opacity(0.3), lineWidth: 1.5)
                )
                .glowShadow(color: config.accentColor, radius: 8)
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.relaxed)
                .fill(Color.black.opacity(0.3))
        )
    }

    private var insightsSidebar: some View {
        VStack(alignment: .leading, spacing: IRISSpacing.md) {
            Text("INSIGHTS")
                .font(IRISTypography.badge)
                .tracking(IRISTypography.badgeTracking)
                .foregroundColor(config.accentColor)

            ScrollView {
                VStack(alignment: .leading, spacing: IRISSpacing.md) {
                    ForEach(Array(parsedResponse.elements.enumerated()), id: \.offset) { _, element in
                        renderInsightElement(element)
                    }
                }
            }
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .stroke(config.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func renderInsightElement(_ element: ICOIResponseElement) -> some View {
        switch element {
        case .heading(_, let text):
            HStack(spacing: IRISSpacing.xs) {
                Text("📍")
                    .font(.system(size: 14))

                Text(text)
                    .irisStyle(.title)
                    .foregroundColor(IRISColors.textPrimary)
            }
            .padding(.top, IRISSpacing.xs)

        case .paragraph(let text):
            Text(text)
                .irisStyle(.body)
                .foregroundColor(IRISColors.textSecondary)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: IRISSpacing.xxs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    insightBullet(item)
                }
            }

        default:
            EmptyView()
        }
    }

    private func insightBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: IRISSpacing.xs) {
            // Trend indicator
            if text.contains("↗") || text.lowercased().contains("up") || text.lowercased().contains("increas") {
                Text("↗")
                    .font(.system(size: 14))
                    .foregroundColor(IRISColors.success)
            } else if text.contains("↘") || text.lowercased().contains("down") || text.lowercased().contains("decreas") {
                Text("↘")
                    .font(.system(size: 14))
                    .foregroundColor(IRISColors.error)
            } else {
                Text("→")
                    .font(.system(size: 14))
                    .foregroundColor(config.accentColor)
            }

            Text(text)
                .irisStyle(.body)
                .foregroundColor(IRISColors.textSecondary)
        }
    }
}
