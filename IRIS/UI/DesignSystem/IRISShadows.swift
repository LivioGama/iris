import SwiftUI

/// IRIS Design System - Shadows
/// Defines depth layers and shadow styles for elevation hierarchy
enum IRISShadows {

    // MARK: - Shadow Levels

    /// Near shadow (subtle elevation)
    /// Radius: 8, Y: 2, Opacity: 0.15
    static func near(color: Color = .black) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 2)
    }

    /// Medium shadow (standard elevation)
    /// Radius: 16, Y: 4, Opacity: 0.25
    static func medium(color: Color = .black) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.25), radius: 16, x: 0, y: 4)
    }

    /// Far shadow (high elevation)
    /// Radius: 32, Y: 8, Opacity: 0.35
    static func far(color: Color = .black) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.35), radius: 32, x: 0, y: 8)
    }

    // MARK: - Specialized Shadows

    /// Glow effect (for accent elements, selections)
    static func glow(color: Color, radius: CGFloat = 16) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.4), radius: radius, x: 0, y: 0)
    }

    /// Inner shadow effect (for inset elements)
    static func inner(color: Color = .black) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Shadow View Modifiers

extension View {
    /// Apply near shadow (subtle elevation)
    func nearShadow(color: Color = .black) -> some View {
        self.shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 2)
    }

    /// Apply medium shadow (standard elevation)
    func mediumShadow(color: Color = .black) -> some View {
        self.shadow(color: color.opacity(0.25), radius: 16, x: 0, y: 4)
    }

    /// Apply far shadow (high elevation)
    func farShadow(color: Color = .black) -> some View {
        self.shadow(color: color.opacity(0.35), radius: 32, x: 0, y: 8)
    }

    /// Apply glow effect
    func glowShadow(color: Color, radius: CGFloat = 16) -> some View {
        self.shadow(color: color.opacity(0.4), radius: radius, x: 0, y: 0)
    }

    /// Apply inner shadow effect
    func innerShadow(color: Color = .black) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(color.opacity(0.1), lineWidth: 1)
                .blur(radius: 2)
                .offset(x: 0, y: 1)
                .mask(RoundedRectangle(cornerRadius: 0).fill(LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )))
        )
    }
}

// MARK: - Elevation Hierarchy

enum IRISElevation {
    /// Base level (no shadow) - Flat elements
    case flat

    /// Level 1 (near shadow) - Slightly elevated cards
    case low

    /// Level 2 (medium shadow) - Standard floating elements
    case medium

    /// Level 3 (far shadow) - High-priority modals, overlays
    case high

    var shadowModifier: (Color) -> AnyView {
        switch self {
        case .flat:
            return { _ in AnyView(EmptyView()) }
        case .low:
            return { color in AnyView(IRISShadows.near(color: color)) }
        case .medium:
            return { color in AnyView(IRISShadows.medium(color: color)) }
        case .high:
            return { color in AnyView(IRISShadows.far(color: color)) }
        }
    }
}

extension View {
    /// Apply elevation-based shadow
    func elevation(_ level: IRISElevation, color: Color = .black) -> some View {
        switch level {
        case .flat:
            return AnyView(self)
        case .low:
            return AnyView(self.nearShadow(color: color))
        case .medium:
            return AnyView(self.mediumShadow(color: color))
        case .high:
            return AnyView(self.farShadow(color: color))
        }
    }
}
