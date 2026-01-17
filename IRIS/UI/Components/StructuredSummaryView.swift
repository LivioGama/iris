import SwiftUI
import IRISCore

/// View for displaying structured summaries with collapsible sections
struct StructuredSummaryView: View {
    let elements: [ICOIResponseElement]
    let onExport: () -> Void

    @State private var expandedSections: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Export button
            HStack {
                Spacer()
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Export summary")
            }

            // Structured content
            VStack(alignment: .leading, spacing: 8) {
                ForEach(elements.indices, id: \.self) { index in
                    renderElement(elements[index])
                }
            }
        }
    }

    @ViewBuilder
    private func renderElement(_ element: ICOIResponseElement) -> some View {
        switch element {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)

        case .paragraph(let text):
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                    }
                }
            }

        case .numberedOption(let number, let title, let content):
            VStack(alignment: .leading, spacing: 4) {
                Text("\(number). \(title)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                if !content.isEmpty {
                    Text(content)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }
            }
            .padding(.vertical, 4)

        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code) {
                // Copy action
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
            }

        case .actionItem(let text, let assignee, let completed):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(completed ? .green : .white.opacity(0.6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .strikethrough(completed)

                    if let assignee = assignee {
                        Text("(\(assignee))")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    private func renderHeading(level: Int, text: String) -> some View {
        let sectionId = "heading-\(level)-\(text.hashValue)"
        let isExpanded = expandedSections.contains(sectionId)

        return Button(action: {
            if isExpanded {
                expandedSections.remove(sectionId)
            } else {
                expandedSections.insert(sectionId)
            }
        }) {
            HStack {
                Text(emojiForHeading(text))
                    .font(.system(size: 16))

                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
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

    private func emojiForHeading(_ text: String) -> String {
        let lowerText = text.lowercased()

        if lowerText.contains("main objectives") || lowerText.contains("objectives") {
            return "🎯"
        } else if lowerText.contains("actions") || lowerText.contains("assigned") {
            return "✅"
        } else if lowerText.contains("decisions") {
            return "📌"
        } else if lowerText.contains("blockers") || lowerText.contains("questions") {
            return "⚠️"
        } else if lowerText.contains("trends") {
            return "📊"
        } else if lowerText.contains("notable") || lowerText.contains("points") {
            return "🔍"
        } else if lowerText.contains("takeaway") {
            return "📈"
        } else if lowerText.contains("title") {
            return "💡"
        } else if lowerText.contains("tone") || lowerText.contains("analysis") {
            return "📝"
        }

        return "📋"
    }
}