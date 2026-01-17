import SwiftUI
import IRISCore

/// Message Reply Mode View - Floating cards conversational layout
/// Displays message response options as individual bubbles
struct MessageReplyModeView: View {
    let parsedResponse: ICOIParsedResponse
    let config: ModeVisualConfig
    let screenshot: NSImage?
    @Binding var selectedOption: Int?

    @State private var hoveredCard: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: IRISSpacing.lg) {
            // Header with mode badge and optional screenshot preview
            HStack(alignment: .top, spacing: IRISSpacing.md) {
                modeBadge

                Spacer()

                // Small screenshot preview in top-right
                if let screenshot = screenshot {
                    Image(nsImage: screenshot)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: IRISRadius.tight))
                        .overlay(
                            RoundedRectangle(cornerRadius: IRISRadius.tight)
                                .stroke(IRISColors.stroke, lineWidth: 1)
                        )
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, IRISSpacing.lg)
            .padding(.top, IRISSpacing.lg)

            // Message option cards
            ScrollView {
                VStack(spacing: IRISSpacing.lg) {
                    ForEach(Array(parsedResponse.numberedOptions.enumerated()), id: \.offset) { index, option in
                        messageCard(
                            number: option.number,
                            title: option.title,
                            content: option.content,
                            index: index
                        )
                        .transition(IRISTransitions.floatUp)
                    }
                }
                .padding(.horizontal, IRISSpacing.lg)
            }
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

    private func messageCard(number: Int, title: String, content: String, index: Int) -> some View {
        let isSelected = selectedOption == number
        let isHovered = hoveredCard == number

        return VStack(alignment: .leading, spacing: IRISSpacing.sm) {
            // Card header with icon and title
            HStack(spacing: IRISSpacing.xs) {
                Text(toneIcon(for: title))
                    .font(.system(size: 18))

                Text(title.uppercased())
                    .font(IRISTypography.badge)
                    .tracking(IRISTypography.badgeTracking)
                    .foregroundColor(config.accentColor)
            }

            // Message content
            Text(content)
                .irisStyle(.body)
                .foregroundColor(IRISColors.textPrimary)
                .textSelection(.enabled)
                .lineLimit(isSelected ? nil : 4)

            // Action buttons
            HStack(spacing: IRISSpacing.xs) {
                Button(action: { copyToClipboard(content) }) {
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
                            .fill(config.accentColor.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

                if !isSelected && content.count > 200 {
                    Button(action: { withAnimation { selectedOption = number } }) {
                        Text("Read more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(config.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.soft)
                .fill(Color.black.opacity(isHovered ? 0.5 : 0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IRISRadius.soft)
                .stroke(
                    LinearGradient(
                        colors: [config.accentColor.opacity(isHovered ? 0.6 : 0.3), config.accentColor.opacity(isHovered ? 0.3 : 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .glowShadow(color: isHovered ? config.accentColor : .clear, radius: 12)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            hoveredCard = hovering ? number : nil
        }
        .onTapGesture {
            withAnimation {
                selectedOption = isSelected ? nil : number
            }
        }
    }

    // MARK: - Helpers

    private func toneIcon(for title: String) -> String {
        let lowercased = title.lowercased()
        if lowercased.contains("direct") || lowercased.contains("concise") {
            return "🎯"
        } else if lowercased.contains("friend") || lowercased.contains("casual") {
            return "✨"
        } else if lowercased.contains("formal") || lowercased.contains("professional") {
            return "💼"
        } else if lowercased.contains("empathetic") || lowercased.contains("warm") {
            return "💬"
        } else {
            return "📝"
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
