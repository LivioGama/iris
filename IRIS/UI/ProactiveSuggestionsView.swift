//
//  ProactiveSuggestionsView.swift
//  IRIS
//
//  Enhanced proactive intent suggestions with improved glassmorphism
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
    @State private var isContextVisible = false

    var body: some View {
        VStack(spacing: 20) {
            // Context label with fade-in
            if !context.isEmpty {
                contextLabel
                    .opacity(isContextVisible ? 1 : 0)
                    .offset(y: isContextVisible ? 0 : -10)
            }

            // Suggestion bubbles with staggered animation
            VStack(spacing: 10) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    suggestionBubble(suggestion, index: index)
                        .irisStaggered(index: index)
                }
            }

            // Custom request hint
            customRequestHint
                .irisStaggered(index: suggestions.count)
        }
        .padding(.horizontal, 40)
        .onAppear {
            withAnimation(.easeOut(duration: IRISAnimationTiming.standard).delay(0.1)) {
                isContextVisible = true
            }
        }
    }

    // MARK: - Context Label

    private var contextLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(IRISProductionColors.geminiBlue.opacity(0.8))

            Text(context)
                .font(.system(size: 13, weight: .light, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
    }

    // MARK: - Suggestion Bubble

    private func suggestionBubble(_ suggestion: ProactiveSuggestion, index: Int) -> some View {
        Button(action: { onSelect(suggestion) }) {
            HStack(spacing: 14) {
                // Number badge with glow
                numberBadge(suggestion.id)

                // Label
                Text(suggestion.label)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                // Confidence indicator
                confidenceIndicator(suggestion.confidence)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(bubbleBackground(isHovered: hoveredId == suggestion.id, confidence: suggestion.confidence))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(bubbleStroke(isHovered: hoveredId == suggestion.id), lineWidth: 1)
            )
            .shadow(
                color: shadowColor(isHovered: hoveredId == suggestion.id),
                radius: hoveredId == suggestion.id ? 25 : 12,
                x: 0,
                y: hoveredId == suggestion.id ? 8 : 4
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeOut(duration: IRISAnimationTiming.quick)) {
                hoveredId = isHovered ? suggestion.id : nil
            }
        }
        .scaleEffect(hoveredId == suggestion.id ? 1.02 : 1.0)
        .animation(IRISAnimationTiming.spring, value: hoveredId)
    }

    // MARK: - Number Badge

    private func numberBadge(_ number: Int) -> some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 36, height: 36)

            // Main badge
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            IRISProductionColors.geminiBlue,
                            IRISProductionColors.geminiPurple
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .shadow(color: IRISProductionColors.geminiBlue.opacity(0.5), radius: 10, y: 3)
    }

    // MARK: - Confidence Indicator

    private func confidenceIndicator(_ confidence: Double) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index < confidenceLevel(confidence)
                        ? IRISProductionColors.geminiBlue
                        : Color.white.opacity(0.15)
                    )
                    .frame(width: 5, height: index < confidenceLevel(confidence) ? 12 : 8)
                    .animation(
                        .easeInOut(duration: 0.3).delay(Double(index) * 0.05),
                        value: confidence
                    )
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
            // Base layer
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)

            // Gradient overlay with confidence-based intensity
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(isHovered ? 0.15 : 0.08),
                            IRISProductionColors.geminiPurple.opacity(isHovered ? 0.12 : 0.05),
                            IRISProductionColors.geminiBlue.opacity(isHovered ? 0.06 : 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Highlight on hover
            if isHovered {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private func bubbleStroke(isHovered: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(isHovered ? 0.4 : 0.2),
                IRISProductionColors.geminiBlue.opacity(isHovered ? 0.3 : 0.15),
                Color.white.opacity(isHovered ? 0.25 : 0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func shadowColor(isHovered: Bool) -> Color {
        isHovered ? IRISProductionColors.geminiBlue.opacity(0.4) : Color.black.opacity(0.25)
    }

    // MARK: - Custom Request Hint

    /// Whether the suggestions were auto-typed (from Live mode propose_reply)
    private var isAutoTyped: Bool {
        suggestions.first?.autoExecute == true
    }

    private var customRequestHint: some View {
        Button(action: onCustomRequest) {
            HStack(spacing: 10) {
                Image(systemName: isAutoTyped ? "arrow.up.circle.fill" : "mic.fill")
                    .font(.system(size: 12))
                    .foregroundColor(IRISProductionColors.geminiBlue.opacity(0.9))
                    .symbolEffect(.pulse, options: .repeating)

                Text(isAutoTyped ? "Say \"send\" to confirm  ·  \"cancel\" to undo" : "Or say something else...")
                    .font(.system(size: 13, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .irisHover(scale: 1.03, lift: -1)
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
