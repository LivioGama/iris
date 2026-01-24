//
//  ProactiveSuggestionsView.swift
//  IRIS
//
//  Displays proactive intent suggestions as clickable/speakable bubbles
//

import SwiftUI
import IRISCore

/// Displays proactive suggestions with numbered bubbles
struct ProactiveSuggestionsView: View {
    let suggestions: [ProactiveSuggestion]
    let context: String
    let onSelect: (ProactiveSuggestion) -> Void
    let onCustomRequest: () -> Void

    @State private var hoveredId: Int? = nil
    @State private var appearedIds: Set<Int> = []

    var body: some View {
        VStack(spacing: 24) {
            // Context label
            if !context.isEmpty {
                Text(context)
                    .font(.system(size: 14, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Suggestion bubbles
            VStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    suggestionBubble(suggestion)
                        .opacity(appearedIds.contains(suggestion.id) ? 1 : 0)
                        .offset(y: appearedIds.contains(suggestion.id) ? 0 : 20)
                        .onAppear {
                            // Staggered animation
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(suggestion.id - 1) * 0.1)) {
                                _ = appearedIds.insert(suggestion.id)
                            }
                        }
                }
            }

            // Custom request hint
            customRequestHint
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Suggestion Bubble

    @ViewBuilder
    private func suggestionBubble(_ suggestion: ProactiveSuggestion) -> some View {
        Button(action: { onSelect(suggestion) }) {
            HStack(spacing: 16) {
                // Number badge
                numberBadge(suggestion.id)

                // Label
                Text(suggestion.label)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                // Confidence indicator (subtle)
                confidenceIndicator(suggestion.confidence)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(bubbleBackground(isHovered: hoveredId == suggestion.id, confidence: suggestion.confidence))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(bubbleStroke(isHovered: hoveredId == suggestion.id), lineWidth: 1)
            )
            .shadow(color: shadowColor(isHovered: hoveredId == suggestion.id).opacity(0.3), radius: hoveredId == suggestion.id ? 20 : 10, y: 5)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeOut(duration: 0.2)) {
                hoveredId = isHovered ? suggestion.id : nil
            }
        }
        .scaleEffect(hoveredId == suggestion.id ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoveredId)
    }

    // MARK: - Number Badge

    @ViewBuilder
    private func numberBadge(_ number: Int) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "4796E3"), Color(hex: "9177C7")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)

            Text("\(number)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .shadow(color: Color(hex: "4796E3").opacity(0.4), radius: 8, y: 2)
    }

    // MARK: - Confidence Indicator

    @ViewBuilder
    private func confidenceIndicator(_ confidence: Double) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < confidenceLevel(confidence) ? Color(hex: "4796E3") : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func confidenceLevel(_ confidence: Double) -> Int {
        if confidence >= 0.8 { return 3 }
        if confidence >= 0.5 { return 2 }
        return 1
    }

    // MARK: - Bubble Styling

    private func bubbleBackground(isHovered: Bool, confidence: Double) -> some View {
        ZStack {
            // Base dark glass
            Color.black.opacity(0.4)

            // Gradient overlay
            LinearGradient(
                colors: [
                    Color(hex: "4796E3").opacity(isHovered ? 0.2 : 0.1),
                    Color(hex: "9177C7").opacity(isHovered ? 0.15 : 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Glass material
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        }
    }

    private func bubbleStroke(isHovered: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(isHovered ? 0.4 : 0.2),
                Color.white.opacity(isHovered ? 0.2 : 0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func shadowColor(isHovered: Bool) -> Color {
        isHovered ? Color(hex: "4796E3") : Color.black
    }

    // MARK: - Custom Request Hint

    @ViewBuilder
    private var customRequestHint: some View {
        Button(action: onCustomRequest) {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "4796E3").opacity(0.8))

                Text("Or say something else...")
                    .font(.system(size: 14, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            // Could add hover effect here
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProactiveSuggestionsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ProactiveSuggestionsView(
                suggestions: [
                    ProactiveSuggestion(id: 1, intent: "code_improvement", label: "Improve this code", confidence: 0.85),
                    ProactiveSuggestion(id: 2, intent: "explain", label: "Explain what this does", confidence: 0.70),
                    ProactiveSuggestion(id: 3, intent: "find_bugs", label: "Find potential bugs", confidence: 0.55)
                ],
                context: "Swift code in Xcode editor",
                onSelect: { _ in },
                onCustomRequest: { }
            )
        }
        .frame(width: 500, height: 400)
    }
}
#endif
