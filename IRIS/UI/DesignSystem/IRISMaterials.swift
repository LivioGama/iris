import SwiftUI

/// IRIS Design System - Materials & Glassmorphism
/// Defines frosted glass effects, blur levels, and material styles
enum IRISMaterials {

    // MARK: - Blur Levels

    /// Light blur (10pt) - Subtle depth, minimal obscuring
    static let lightBlur: CGFloat = 10

    /// Medium blur (15pt) - Standard glassmorphism
    static let mediumBlur: CGFloat = 15

    /// Heavy blur (20pt) - Maximum depth, strong material effect
    static let heavyBlur: CGFloat = 20

    // MARK: - Material Styles

    /// Primary frosted glass surface
    static let primaryGlass = Material.ultraThinMaterial

    /// Secondary frosted glass surface (more transparent)
    static let secondaryGlass = Material.thin

    /// Thick material for modals and overlays
    static let thickGlass = Material.thick

    // MARK: - Stroke/Border Styles

    /// Standard stroke width
    static let strokeWidth: CGFloat = 1.0

    /// Thin stroke width
    static let strokeWidthThin: CGFloat = 0.5

    /// Thick stroke width (for emphasis)
    static let strokeWidthThick: CGFloat = 1.5
}

// MARK: - Glass Effect View Modifier

struct GlassEffect: ViewModifier {
    let blur: CGFloat
    let stroke: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.05))
                    .blur(radius: blur)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(stroke ? IRISColors.stroke : Color.clear, lineWidth: IRISMaterials.strokeWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    /// Apply glass effect with blur and optional stroke
    func glassEffect(
        blur: CGFloat = IRISMaterials.mediumBlur,
        stroke: Bool = true,
        cornerRadius: CGFloat = IRISSpacing.md
    ) -> some View {
        self.modifier(GlassEffect(blur: blur, stroke: stroke, cornerRadius: cornerRadius))
    }
}

// MARK: - Spacing System

enum IRISSpacing {
    /// 2pt - Minimal spacing
    static let xxxs: CGFloat = 2

    /// 4pt - Extra extra small
    static let xxs: CGFloat = 4

    /// 8pt - Extra small (baseline)
    static let xs: CGFloat = 8

    /// 12pt - Small
    static let sm: CGFloat = 12

    /// 16pt - Medium (default)
    static let md: CGFloat = 16

    /// 24pt - Large
    static let lg: CGFloat = 24

    /// 32pt - Extra large
    static let xl: CGFloat = 32

    /// 48pt - Extra extra large
    static let xxl: CGFloat = 48

    /// 64pt - Extra extra extra large
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius System

enum IRISRadius {
    /// 8pt - Tight corners (buttons, tags)
    static let tight: CGFloat = 8

    /// 12pt - Normal corners (cards, panels)
    static let normal: CGFloat = 12

    /// 16pt - Relaxed corners (larger cards)
    static let relaxed: CGFloat = 16

    /// 20pt - Soft corners (message bubbles)
    static let soft: CGFloat = 20

    /// 32pt - Round corners (special elements)
    static let round: CGFloat = 32
}
