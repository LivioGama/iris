import SwiftUI
import IRISCore

/// View for displaying code blocks with syntax highlighting and copy functionality
struct CodeBlockView: View {
    let language: String
    let code: String
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language badge and copy button
            HStack {
                Text(language.isEmpty ? "text" : language)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                    )

                Spacer()

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Copy code")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Code content
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .lineSpacing(2)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}