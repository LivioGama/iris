import SwiftUI

/// IRIS Design System - Typography
/// Defines text styles, weights, and hierarchical type scale
enum IRISTextStyle {
    /// Hero text (28pt, semibold) - Mode titles, major headings
    case hero

    /// Title text (20pt, medium) - Section headers, card titles
    case title

    /// Body text (15pt, regular) - Primary content, paragraphs
    case body

    /// Caption text (12pt, medium) - Metadata, labels, timestamps
    case caption

    /// Code text (13pt SF Mono, regular) - Monospace code blocks
    case code

    // MARK: - Typography Specifications

    var fontSize: CGFloat {
        switch self {
        case .hero: return 28
        case .title: return 20
        case .body: return 15
        case .caption: return 12
        case .code: return 13
        }
    }

    var weight: Font.Weight {
        switch self {
        case .hero: return .semibold
        case .title: return .medium
        case .body: return .regular
        case .caption: return .medium
        case .code: return .regular
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .hero: return 1.2
        case .title: return 1.3
        case .body: return 1.5
        case .caption: return 1.4
        case .code: return 1.4
        }
    }

    var tracking: CGFloat {
        switch self {
        case .hero: return -0.5
        case .title: return -0.3
        case .body: return 0
        case .caption: return 0.2
        case .code: return 0
        }
    }

    var font: Font {
        switch self {
        case .code:
            return .system(size: fontSize, weight: weight, design: .monospaced)
        default:
            return .system(size: fontSize, weight: weight, design: .default)
        }
    }
}

// MARK: - SwiftUI Text Extensions

extension Text {
    /// Apply IRIS text style with proper spacing and tracking
    func irisStyle(_ style: IRISTextStyle) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.fontSize * (style.lineHeight - 1.0))
    }
}

extension View {
    /// Apply IRIS text style as a view modifier
    func irisTextStyle(_ style: IRISTextStyle) -> some View {
        self.modifier(IRISTextStyleModifier(style: style))
    }
}

// MARK: - Text Style View Modifier

struct IRISTextStyleModifier: ViewModifier {
    let style: IRISTextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.fontSize * (style.lineHeight - 1.0))
    }
}

// MARK: - Specialized Typography Variants

enum IRISTypography {

    // MARK: - Mode-Specific Adjustments

    /// Code mode text styles (optimized for code readability)
    static func codeStyle(size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Message mode text styles (warmer, more conversational)
    static func messageStyle(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Semantic Text Styles

    /// Badge text (small, uppercase, tracked)
    static let badge = Font.system(size: 11, weight: .semibold, design: .default)
    static let badgeTracking: CGFloat = 1.0

    /// Button text (medium, slightly tracked)
    static let button = Font.system(size: 14, weight: .medium, design: .default)
    static let buttonTracking: CGFloat = 0.3

    /// Link text (same as body but with different color)
    static let link = Font.system(size: 15, weight: .medium, design: .default)

    /// Error/warning text
    static let alert = Font.system(size: 13, weight: .medium, design: .default)

    // MARK: - Line Number Typography (Code Mode)

    /// Line numbers for code blocks
    static let lineNumber = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let lineNumberColor = IRISColors.textDimmed

    // MARK: - Helper Methods

    /// Apply badge style with proper tracking
    static func applyBadgeStyle(to text: Text) -> some View {
        text
            .font(badge)
            .tracking(badgeTracking)
            .textCase(.uppercase)
    }

    /// Apply button style with proper tracking
    static func applyButtonStyle(to text: Text) -> some View {
        text
            .font(button)
            .tracking(buttonTracking)
    }
}
