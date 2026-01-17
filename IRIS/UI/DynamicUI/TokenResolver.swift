import SwiftUI
import IRISCore

/// Resolves design tokens to concrete SwiftUI values.
/// This ensures primitives use the existing design system (IRISSpacing, IRISRadius, IRISColors).
enum TokenResolver {

    // MARK: - Spacing

    /// Resolve spacing token to CGFloat
    static func spacing(_ token: SpacingToken?) -> CGFloat {
        guard let token = token else { return 0 }
        switch token {
        case .none: return 0
        case .xxs: return IRISSpacing.xxs
        case .xs: return IRISSpacing.xs
        case .sm: return IRISSpacing.sm
        case .md: return IRISSpacing.md
        case .lg: return IRISSpacing.lg
        case .xl: return IRISSpacing.xl
        case .xxl: return IRISSpacing.xxl
        }
    }

    // MARK: - Radius

    /// Resolve radius token to CGFloat
    static func radius(_ token: RadiusToken?) -> CGFloat {
        guard let token = token else { return IRISRadius.normal }
        switch token {
        case .none: return 0
        case .tight: return IRISRadius.tight
        case .normal: return IRISRadius.normal
        case .relaxed: return IRISRadius.relaxed
        case .soft: return IRISRadius.soft
        case .round: return IRISRadius.round
        case .full: return 999
        }
    }

    // MARK: - Colors

    /// Resolve color token to SwiftUI Color
    static func color(_ token: ColorToken?, theme: UITheme) -> Color {
        guard let token = token else { return IRISColors.textPrimary }
        switch token {
        case .primary:
            return IRISColors.textPrimary
        case .secondary:
            return IRISColors.textSecondary
        case .accent:
            return Color(hex: theme.accentColor)
        case .accentSecondary:
            return Color(hex: theme.secondaryColor ?? theme.accentColor)
        case .muted:
            return IRISColors.textTertiary
        case .success:
            return IRISColors.success
        case .warning:
            return IRISColors.warning
        case .error:
            return IRISColors.error
        case .info:
            return IRISColors.info
        }
    }

    // MARK: - Text Sizing

    /// Resolve text size token to Font
    static func font(size: TextSizeToken?, weight: TextWeightToken?, family: FontFamilyToken?) -> Font {
        let baseSize: CGFloat
        switch size ?? .body {
        case .display: baseSize = 34
        case .title: baseSize = 24
        case .headline: baseSize = 18
        case .body: baseSize = 14
        case .caption: baseSize = 12
        case .micro: baseSize = 10
        }

        let fontWeight: Font.Weight
        switch weight ?? .regular {
        case .light: fontWeight = .light
        case .regular: fontWeight = .regular
        case .medium: fontWeight = .medium
        case .semibold: fontWeight = .semibold
        case .bold: fontWeight = .bold
        case .heavy: fontWeight = .heavy
        }

        let design: Font.Design
        switch family ?? .system {
        case .system: design = .default
        case .rounded: design = .rounded
        case .monospace: design = .monospaced
        case .serif: design = .serif
        }

        return Font.system(size: baseSize, weight: fontWeight, design: design)
    }

    // MARK: - Background

    /// Resolve background token to a View
    @ViewBuilder
    static func background(_ token: BackgroundToken?, theme: UITheme, semantic: String?) -> some View {
        let resolvedToken = token ?? .none

        switch resolvedToken {
        case .none:
            Color.clear

        case .glass:
            glassBackground(dark: false, theme: theme)

        case .glassDark:
            glassBackground(dark: true, theme: theme)

        case .solid:
            Color(hex: theme.accentColor).opacity(0.15)

        case .solidSubtle:
            Color(hex: theme.accentColor).opacity(0.08)

        case .gradient:
            LinearGradient(
                colors: [
                    Color(hex: theme.accentColor),
                    Color(hex: theme.secondaryColor ?? theme.accentColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.2)
        }
    }

    /// Create glassmorphic background
    @ViewBuilder
    private static func glassBackground(dark: Bool, theme: UITheme) -> some View {
        ZStack {
            // Base material
            if dark {
                Color.black.opacity(0.4)
            } else {
                Color.black.opacity(0.2)
            }

            // Subtle gradient overlay using theme colors
            LinearGradient(
                colors: [
                    Color(hex: theme.accentColor).opacity(0.05),
                    Color(hex: theme.secondaryColor ?? theme.accentColor).opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Border

    /// Resolve border token to stroke style
    static func borderColor(_ token: BorderToken?, theme: UITheme) -> Color {
        guard let token = token, token != .none else {
            return Color.clear
        }
        switch token {
        case .none:
            return Color.clear
        case .subtle:
            return IRISColors.stroke.opacity(0.5)
        case .normal:
            return IRISColors.stroke
        case .accent:
            return Color(hex: theme.accentColor).opacity(0.5)
        case .gradient:
            // For gradient borders, return accent as fallback
            return Color(hex: theme.accentColor).opacity(0.3)
        }
    }

    static func borderWidth(_ token: BorderToken?) -> CGFloat {
        guard let token = token, token != .none else { return 0 }
        switch token {
        case .none: return 0
        case .subtle: return IRISMaterials.strokeWidthThin
        case .normal, .accent, .gradient: return IRISMaterials.strokeWidth
        }
    }

    // MARK: - Size Constraints

    /// Resolve size token to optional CGFloat (nil means no constraint)
    static func size(_ token: SizeToken?, in geometry: CGFloat) -> CGFloat? {
        guard let token = token else { return nil }
        switch token {
        case .auto: return nil
        case .full: return geometry
        case .half: return geometry * 0.5
        case .third: return geometry * 0.333
        case .quarter: return geometry * 0.25
        }
    }

    // MARK: - Alignment

    /// Convert LayoutAlignment to SwiftUI HorizontalAlignment
    static func horizontalAlignment(_ alignment: LayoutAlignment?) -> HorizontalAlignment {
        switch alignment ?? .leading {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// Convert LayoutAlignment to SwiftUI VerticalAlignment
    static func verticalAlignment(_ alignment: LayoutAlignment?) -> VerticalAlignment {
        switch alignment ?? .center {
        case .leading: return .top
        case .center: return .center
        case .trailing: return .bottom
        }
    }

    /// Convert LayoutAlignment to SwiftUI Alignment
    static func alignment(_ alignment: LayoutAlignment?) -> Alignment {
        switch alignment ?? .leading {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
