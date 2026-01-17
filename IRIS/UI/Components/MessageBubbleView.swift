import SwiftUI
import IRISCore

/// View for displaying message reply options in a chat bubble format
/// Used for message reply intent to show suggestions in a more natural messaging style
struct MessageBubbleView: View {
    let options: [(number: Int, title: String, content: String)]
    let onOptionSelected: (Int) -> Void
    let onOptionCopied: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggested Replies")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 12) {
                ForEach(options, id: \.number) { option in
                    messageBubble(for: option)
                }
            }
        }
    }

    private func messageBubble(for option: (number: Int, title: String, content: String)) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Option label
            HStack {
                Text(option.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                    )

                Spacer()
            }

            // Message bubble
            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    // Message content
                    Text(option.content)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            bubbleShape()
                                .fill(bubbleColor(for: option.number))
                        )
                        .textSelection(.enabled)

                    // Action buttons below bubble
                    HStack(spacing: 12) {
                        Button(action: {
                            onOptionCopied(option.number)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                Text("Copy")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("Copy this reply")
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }

                        Button(action: {
                            onOptionSelected(option.number)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 10))
                                Text("Use")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.3))
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Use this reply")
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .padding(.top, 6)
                    .padding(.trailing, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func bubbleShape() -> some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 4,
            topTrailingRadius: 16
        )
    }

    private func bubbleColor(for optionNumber: Int) -> Color {
        switch optionNumber {
        case 1: // Empathetic
            return Color.purple.opacity(0.4)
        case 2: // Concise
            return Color.blue.opacity(0.4)
        case 3: // Assertive
            return Color.green.opacity(0.4)
        default:
            return Color.gray.opacity(0.4)
        }
    }
}
