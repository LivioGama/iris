import SwiftUI
import IRISCore

/// View for displaying old vs new code side by side for code improvement intent
/// Replaces screenshot with side-by-side code comparison
struct CodeComparisonView: View {
    let oldCode: String
    let newCode: String
    let language: String
    let improvements: [String]
    let onCopyNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with improvements
            if !improvements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Improvements")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    ForEach(Array(improvements.enumerated()), id: \.offset) { _, improvement in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.green.opacity(0.8))
                            Text(improvement)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            }

            // Side-by-side code comparison
            HStack(alignment: .top, spacing: 12) {
                // Old code
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Original")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red.opacity(0.2))
                            )

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))

                    // Code content
                    ScrollView([.vertical, .horizontal]) {
                        Text(oldCode)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .textSelection(.enabled)
                            .padding(12)
                            .lineSpacing(2)
                    }
                    .frame(maxHeight: 400)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )

                // Arrow indicator
                VStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 20))
                    Spacer()
                }
                .frame(width: 30)

                // New code
                VStack(alignment: .leading, spacing: 0) {
                    // Header with copy button
                    HStack {
                        Text("Improved")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green.opacity(0.2))
                            )

                        Spacer()

                        Button(action: onCopyNew) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                Text("Copy")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green.opacity(0.3))
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Copy improved code")
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))

                    // Code content
                    ScrollView([.vertical, .horizontal]) {
                        Text(newCode)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.95))
                            .textSelection(.enabled)
                            .padding(12)
                            .lineSpacing(2)
                    }
                    .frame(maxHeight: 400)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}
