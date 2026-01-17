import SwiftUI
import IRISCore

/// Interactive view for selecting numbered options in ICOI responses
/// Displays clickable numbered options with copy/use actions
struct OptionSelectionView: View {
    let options: [(number: Int, title: String, content: String)]
    let onOptionSelected: (Int) -> Void
    let onOptionCopied: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options, id: \.number) { option in
                optionButton(for: option)
            }
        }
    }

    private func optionButton(for option: (number: Int, title: String, content: String)) -> some View {
        Button(action: {
            onOptionSelected(option.number)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Header with number and title
                HStack {
                    Text("**Option \(option.number): \(option.title)**")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        Button(action: {
                            onOptionCopied(option.number)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Copy this option")

                        Button(action: {
                            onOptionSelected(option.number)
                        }) {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Use this option")
                    }
                }

                // Content
                if !option.content.isEmpty {
                    Text(option.content)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}