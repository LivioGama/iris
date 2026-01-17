import SwiftUI

// MARK: - Glassmorphic Effects for IRIS

/// View extension for applying glassmorphic effects with mode-specific tints
extension View {
    /// Applies glassmorphic material with mode-specific color tint
    func glassmorphic(config: ModeVisualConfig, intensity: Double = 0.3) -> some View {
        self.modifier(GlassmorphicModifier(config: config, intensity: intensity))
    }
}

// MARK: - Glassmorphic Modifier

struct GlassmorphicModifier: ViewModifier {
    let config: ModeVisualConfig
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Ultra-thin material for frosted glass effect
                    Rectangle()
                        .fill(Material.ultraThinMaterial)
                        .opacity(0.95)

                    // Mode-specific color tint overlay
                    config.accentColor
                        .opacity(intensity * 0.15)
                        .blendMode(.plusLighter)

                    // Subtle gradient overlay for depth
                    LinearGradient(
                        colors: [
                            config.accentColor.opacity(intensity * 0.08),
                            Color.clear,
                            config.accentColor.opacity(intensity * 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
    }
}

// MARK: - Border Glow Effect

extension View {
    /// Adds a glowing border using the mode's accent color
    func glowingBorder(config: ModeVisualConfig, lineWidth: CGFloat = 1.5) -> some View {
        self.modifier(GlowingBorderModifier(config: config, lineWidth: lineWidth))
    }
}

struct GlowingBorderModifier: ViewModifier {
    let config: ModeVisualConfig
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        let shape = config.shapeForMode()

        return content
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                config.accentColor.opacity(0.8),
                                config.accentColor.opacity(0.4),
                                config.accentColor.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
                    .blur(radius: 1)
            )
            .overlay(
                shape
                    .stroke(
                        config.accentColor.opacity(0.3),
                        lineWidth: lineWidth * 0.5
                    )
                    .blur(radius: 3)
            )
    }
}

// MARK: - Floating Shadow Effect

extension View {
    /// Adds deep, floating shadow with mode-specific color accent
    func floatingShadow(config: ModeVisualConfig, radius: CGFloat = 40) -> some View {
        self.modifier(FloatingShadowModifier(config: config, radius: radius))
    }
}

struct FloatingShadowModifier: ViewModifier {
    let config: ModeVisualConfig
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: Color.black.opacity(0.5), radius: radius, x: 0, y: 10)
            .shadow(color: config.accentColor.opacity(0.2), radius: radius * 0.5, x: 0, y: 5)
    }
}

// MARK: - Content-Adaptive Sizing

/// Preference key for tracking content size
struct ContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(
            width: max(value.width, next.width),
            height: max(value.height, next.height)
        )
    }
}

extension View {
    /// Measures the view's size and reports it via preference key
    func measureSize() -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ContentSizePreferenceKey.self,
                    value: geometry.size
                )
            }
        )
    }
}

// MARK: - Mode-Specific Size Constraints

extension ModeVisualConfig {
    /// Returns the appropriate size constraints for this mode
    var sizeConstraints: (minWidth: CGFloat, maxWidth: CGFloat, minHeight: CGFloat, maxHeight: CGFloat) {
        switch layoutStyle {
        case .splitPane:
            // Code Improvement: Wide for side-by-side code
            return (800, 1200, 500, 900)
        case .floatingCards:
            // Message Reply: Medium, flexible
            return (500, 800, 400, 700)
        case .verticalSections:
            // Summarize: Wide, tall for document-style
            return (700, 1000, 600, 1000)
        case .dualPanel:
            // Tone Feedback: Balanced, medium
            return (700, 1000, 500, 800)
        case .largeCanvas:
            // Chart Analysis: Extra wide, landscape
            return (900, 1400, 600, 900)
        case .flexible:
            // General: Compact, adaptable
            return (400, 700, 300, 600)
        }
    }
}
