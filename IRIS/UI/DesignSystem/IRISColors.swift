import SwiftUI

/// IRIS Design System - Color Palette
/// Defines mode-specific gradients, backgrounds, and semantic colors
extension Color {
    /// Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Color palette for IRIS mode system
enum IRISColors {

    // MARK: - Mode-Specific Gradients

    /// Code Improvement Mode - Analytical, Precise
    /// Cyan → Electric Blue gradient
    static let codeImprovementGradient = LinearGradient(
        colors: [Color(hex: "00D4FF"), Color(hex: "0066FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Message Reply Mode - Conversational, Empathetic
    /// Purple → Pink gradient
    static let messageReplyGradient = LinearGradient(
        colors: [Color(hex: "9333EA"), Color(hex: "EC4899")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Summarize Mode - Editorial, Structured
    /// Amber → Orange gradient
    static let summarizeGradient = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "F97316")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Tone Feedback Mode - Critical, Nuanced
    /// Teal → Emerald gradient
    static let toneFeedbackGradient = LinearGradient(
        colors: [Color(hex: "14B8A6"), Color(hex: "10B981")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Chart Analysis Mode - Investigative, Data-driven
    /// Cyan → Sky gradient
    static let chartAnalysisGradient = LinearGradient(
        colors: [Color(hex: "06B6D4"), Color(hex: "0EA5E9")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// General Mode - Exploratory, Adaptive
    /// Neutral gradient
    static let generalGradient = LinearGradient(
        colors: [Color(hex: "6B7280"), Color(hex: "9CA3AF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Mode-Specific Backgrounds

    /// Code Improvement Mode background - Darker, code-editor-like
    static let codeImprovementBackground = Color(
        red: 15/255,
        green: 15/255,
        blue: 20/255,
        opacity: 0.95
    )

    /// Message Reply Mode background - Warmer tone
    static let messageReplyBackground = Color(
        red: 30/255,
        green: 20/255,
        blue: 40/255,
        opacity: 0.92
    )

    /// Summarize Mode background - Neutral
    static let summarizeBackground = Color(
        red: 20/255,
        green: 20/255,
        blue: 25/255,
        opacity: 0.93
    )

    /// Tone Feedback Mode background - Balanced
    static let toneFeedbackBackground = Color(
        red: 18/255,
        green: 25/255,
        blue: 28/255,
        opacity: 0.94
    )

    /// Chart Analysis Mode background - Cool tone
    static let chartAnalysisBackground = Color(
        red: 15/255,
        green: 20/255,
        blue: 30/255,
        opacity: 0.95
    )

    /// General Mode background - Balanced
    static let generalBackground = Color(
        red: 20/255,
        green: 20/255,
        blue: 24/255,
        opacity: 0.92
    )

    // MARK: - Mode-Specific Accent Colors (Solid)

    /// Code Improvement accent
    static let codeImprovementAccent = Color(hex: "0066FF")

    /// Message Reply accent
    static let messageReplyAccent = Color(hex: "EC4899")

    /// Summarize accent
    static let summarizeAccent = Color(hex: "F59E0B")

    /// Tone Feedback accent
    static let toneFeedbackAccent = Color(hex: "10B981")

    /// Chart Analysis accent
    static let chartAnalysisAccent = Color(hex: "0EA5E9")

    /// General accent
    static let generalAccent = Color(hex: "9CA3AF")

    // MARK: - Semantic Colors

    /// Success state (green)
    static let success = Color(hex: "10B981")

    /// Error state (red)
    static let error = Color(hex: "EF4444")

    /// Warning state (yellow)
    static let warning = Color(hex: "F59E0B")

    /// Info state (blue)
    static let info = Color(hex: "3B82F6")

    // MARK: - UI Element Colors

    /// Primary text color (high contrast white)
    static let textPrimary = Color.white.opacity(0.95)

    /// Secondary text color (medium contrast)
    static let textSecondary = Color.white.opacity(0.7)

    /// Tertiary text color (low contrast)
    static let textTertiary = Color.white.opacity(0.5)

    /// Dimmed text color (very low contrast)
    static let textDimmed = Color.white.opacity(0.3)

    /// Stroke/border color
    static let stroke = Color.white.opacity(0.2)

    /// Stroke hover state
    static let strokeHover = Color.white.opacity(0.35)

    /// Divider color
    static let divider = Color.white.opacity(0.15)

    // MARK: - Code Syntax Colors (for Code Improvement Mode)

    /// Syntax highlighting - Keywords
    static let syntaxKeyword = Color(hex: "FF79C6")

    /// Syntax highlighting - Strings
    static let syntaxString = Color(hex: "50FA7B")

    /// Syntax highlighting - Comments
    static let syntaxComment = Color(hex: "6272A4")

    /// Syntax highlighting - Functions
    static let syntaxFunction = Color(hex: "8BE9FD")

    /// Syntax highlighting - Numbers
    static let syntaxNumber = Color(hex: "BD93F9")

    // MARK: - Diff Colors (for Code Improvement Mode)

    /// Diff addition (green with low opacity)
    static let diffAdded = Color(hex: "50FA7B").opacity(0.15)

    /// Diff removal (red with low opacity)
    static let diffRemoved = Color(hex: "FF5555").opacity(0.15)

    /// Diff modification (orange with low opacity)
    static let diffModified = Color(hex: "FFB86C").opacity(0.15)

    /// Diff addition border
    static let diffAddedBorder = Color(hex: "50FA7B")

    /// Diff removal border
    static let diffRemovedBorder = Color(hex: "FF5555")

    /// Diff modification border
    static let diffModifiedBorder = Color(hex: "FFB86C")

    // MARK: - Tone Indicators (for Tone Feedback Mode)

    /// Aggressive tone marker (red)
    static let toneAggressive = Color(hex: "EF4444")

    /// Passive tone marker (yellow)
    static let tonePassive = Color(hex: "F59E0B")

    /// Formal tone marker (green)
    static let toneFormal = Color(hex: "10B981")

    /// Casual tone marker (blue)
    static let toneCasual = Color(hex: "3B82F6")

    // MARK: - Helper Methods

    /// Get gradient for specific intent
    static func gradient(for intent: String) -> LinearGradient {
        switch intent.lowercased() {
        case "codeimprovement":
            return codeImprovementGradient
        case "messagereply":
            return messageReplyGradient
        case "summarize":
            return summarizeGradient
        case "tonefeedback":
            return toneFeedbackGradient
        case "chartanalysis":
            return chartAnalysisGradient
        default:
            return generalGradient
        }
    }

    /// Get background color for specific intent
    static func background(for intent: String) -> Color {
        switch intent.lowercased() {
        case "codeimprovement":
            return codeImprovementBackground
        case "messagereply":
            return messageReplyBackground
        case "summarize":
            return summarizeBackground
        case "tonefeedback":
            return toneFeedbackBackground
        case "chartanalysis":
            return chartAnalysisBackground
        default:
            return generalBackground
        }
    }

    /// Get solid accent color for specific intent
    static func accent(for intent: String) -> Color {
        switch intent.lowercased() {
        case "codeimprovement":
            return codeImprovementAccent
        case "messagereply":
            return messageReplyAccent
        case "summarize":
            return summarizeAccent
        case "tonefeedback":
            return toneFeedbackAccent
        case "chartanalysis":
            return chartAnalysisAccent
        default:
            return generalAccent
        }
    }
}
