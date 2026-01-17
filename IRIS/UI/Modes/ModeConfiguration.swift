import SwiftUI

// MARK: - Mode Visual Configuration Protocol

/// Protocol defining visual configuration for each mode
protocol ModeVisualConfig {
    /// Accent gradient for the mode
    var accentGradient: LinearGradient { get }

    /// Background color for the mode
    var backgroundColor: Color { get }

    /// Solid accent color (extracted from gradient)
    var accentColor: Color { get }

    /// Layout style enum
    var layoutStyle: LayoutStyle { get }

    /// Animation configuration
    var animationTiming: Animation { get }

    /// Gaze indicator configuration
    var gazeIndicatorStyle: GazeIndicatorConfig { get }

    /// Screenshot treatment configuration
    var screenshotTreatment: ScreenshotConfig { get }

    /// Mode display name
    var displayName: String { get }

    /// Mode icon/emoji
    var icon: String { get }
}

// MARK: - Supporting Enums

/// Layout style for each mode
enum LayoutStyle {
    case splitPane          // Code Improvement (Before/After)
    case floatingCards      // Message Reply (Card bubbles)
    case verticalSections   // Summarize (Editorial layout)
    case dualPanel          // Tone Feedback (Original + Analysis)
    case largeCanvas        // Chart Analysis (Chart + Sidebar)
    case flexible           // General (Adaptive)
}

/// Gaze indicator configuration
struct GazeIndicatorConfig {
    let color: Color
    let animationStyle: GazeAnimationStyle
    let size: GazeSize

    enum GazeAnimationStyle {
        case pulse
        case glow
        case steady
        case ripple
        case snap
        case minimal
    }

    enum GazeSize {
        case small
        case standard
        case large
        case precision

        var scale: CGFloat {
            switch self {
            case .small: return 0.8
            case .standard: return 1.0
            case .large: return 1.2
            case .precision: return 0.9
            }
        }
    }
}

/// Screenshot treatment configuration
struct ScreenshotConfig {
    let visible: Bool
    let position: ScreenshotPosition
    let size: ScreenshotSize
    let opacity: Double

    enum ScreenshotPosition {
        case topLeft
        case topFull
        case leftPanel
        case background
        case hidden
    }

    enum ScreenshotSize {
        case small      // 200x150
        case medium     // 400x300
        case large      // 600x450
        case fullWidth  // Container width
    }
}

// MARK: - Code Improvement Mode Configuration

struct CodeImprovementConfig: ModeVisualConfig {
    let accentGradient = IRISColors.codeImprovementGradient
    let backgroundColor = IRISColors.codeImprovementBackground
    let accentColor = IRISColors.codeImprovementAccent
    let layoutStyle: LayoutStyle = .splitPane
    let animationTiming = IRISAnimations.snappy
    let displayName = "Code Improvement"
    let icon = "💻"

    let gazeIndicatorStyle = GazeIndicatorConfig(
        color: IRISColors.codeImprovementAccent,
        animationStyle: .pulse,
        size: .standard
    )

    let screenshotTreatment = ScreenshotConfig(
        visible: false,  // Hidden in code mode (focus on code)
        position: .hidden,
        size: .medium,
        opacity: 0.7
    )
}

// MARK: - Message Reply Mode Configuration

struct MessageReplyConfig: ModeVisualConfig {
    let accentGradient = IRISColors.messageReplyGradient
    let backgroundColor = IRISColors.messageReplyBackground
    let accentColor = IRISColors.messageReplyAccent
    let layoutStyle: LayoutStyle = .floatingCards
    let animationTiming = IRISAnimations.bouncy
    let displayName = "Message Reply"
    let icon = "💬"

    let gazeIndicatorStyle = GazeIndicatorConfig(
        color: IRISColors.messageReplyAccent,
        animationStyle: .glow,
        size: .large
    )

    let screenshotTreatment = ScreenshotConfig(
        visible: true,
        position: .topLeft,
        size: .small,
        opacity: 0.6
    )
}

// MARK: - Summarize Mode Configuration

struct SummarizeConfig: ModeVisualConfig {
    let accentGradient = IRISColors.summarizeGradient
    let backgroundColor = IRISColors.summarizeBackground
    let accentColor = IRISColors.summarizeAccent
    let layoutStyle: LayoutStyle = .verticalSections
    let animationTiming = IRISAnimations.smoothSpring
    let displayName = "Summary"
    let icon = "📄"

    let gazeIndicatorStyle = GazeIndicatorConfig(
        color: IRISColors.summarizeAccent,
        animationStyle: .steady,
        size: .standard
    )

    let screenshotTreatment = ScreenshotConfig(
        visible: true,
        position: .topFull,
        size: .fullWidth,
        opacity: 0.5
    )
}

// MARK: - Tone Feedback Mode Configuration

struct ToneFeedbackConfig: ModeVisualConfig {
    let accentGradient = IRISColors.toneFeedbackGradient
    let backgroundColor = IRISColors.toneFeedbackBackground
    let accentColor = IRISColors.toneFeedbackAccent
    let layoutStyle: LayoutStyle = .dualPanel
    let animationTiming = IRISAnimations.smoothSpring
    let displayName = "Tone Analysis"
    let icon = "📝"

    let gazeIndicatorStyle = GazeIndicatorConfig(
        color: IRISColors.toneFeedbackAccent,
        animationStyle: .ripple,
        size: .standard
    )

    let screenshotTreatment = ScreenshotConfig(
        visible: true,
        position: .leftPanel,
        size: .medium,
        opacity: 0.8
    )
}

// MARK: - Chart Analysis Mode Configuration

struct ChartAnalysisConfig: ModeVisualConfig {
    let accentGradient = IRISColors.chartAnalysisGradient
    let backgroundColor = IRISColors.chartAnalysisBackground
    let accentColor = IRISColors.chartAnalysisAccent
    let layoutStyle: LayoutStyle = .largeCanvas
    let animationTiming = IRISAnimations.snappy
    let displayName = "Chart Analysis"
    let icon = "📊"

    let gazeIndicatorStyle = GazeIndicatorConfig(
        color: IRISColors.chartAnalysisAccent,
        animationStyle: .snap,
        size: .precision
    )

    let screenshotTreatment = ScreenshotConfig(
        visible: true,
        position: .leftPanel,
        size: .large,
        opacity: 1.0
    )
}

// MARK: - General Mode Configuration

struct GeneralConfig: ModeVisualConfig {
    let accentGradient = IRISColors.generalGradient
    let backgroundColor = IRISColors.generalBackground
    let accentColor = IRISColors.generalAccent
    let layoutStyle: LayoutStyle = .flexible
    let animationTiming = IRISAnimations.bouncy
    let displayName = "IRIS Assistant"
    let icon = "✨"

    let gazeIndicatorStyle = GazeIndicatorConfig(
        color: IRISColors.generalAccent,
        animationStyle: .minimal,
        size: .small
    )

    let screenshotTreatment = ScreenshotConfig(
        visible: false,  // Only show if referenced
        position: .background,
        size: .medium,
        opacity: 0.4
    )
}

// MARK: - Mode Configuration Factory

enum ModeConfigurationFactory {
    /// Get configuration for a specific mode string
    static func config(for mode: String) -> ModeVisualConfig {
        switch mode.lowercased() {
        case "codeimprovement":
            return CodeImprovementConfig()
        case "messagereply":
            return MessageReplyConfig()
        case "summarize":
            return SummarizeConfig()
        case "tonefeedback":
            return ToneFeedbackConfig()
        case "chartanalysis":
            return ChartAnalysisConfig()
        default:
            return GeneralConfig()
        }
    }
}
