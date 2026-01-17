import SwiftUI

// MARK: - Mode-Specific Organic Shapes

/// Custom shapes for each mode to create organic, non-rectangular overlays
enum ModeShape {
    case codeImprovement
    case messageReply
    case summarize
    case toneFeedback
    case chartAnalysis
    case general
}

// MARK: - Code Improvement Shape (Split Vertical Pill)

/// Two connected vertical pills representing before/after code
struct CodeImprovementShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 24
        let centerGap: CGFloat = 8

        // Left pill
        let leftRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: (rect.width / 2) - (centerGap / 2),
            height: rect.height
        )
        path.addRoundedRect(in: leftRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        // Right pill
        let rightRect = CGRect(
            x: rect.midX + (centerGap / 2),
            y: rect.minY,
            width: (rect.width / 2) - (centerGap / 2),
            height: rect.height
        )
        path.addRoundedRect(in: rightRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        return path
    }
}

// MARK: - Message Reply Shape (Chat Bubble)

/// Organic chat bubble with subtle tail
struct MessageReplyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 28
        let tailHeight: CGFloat = 12
        let tailWidth: CGFloat = 20

        // Main bubble (rounded rectangle)
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tailHeight
        )

        // Create rounded rectangle path
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        // Add subtle tail at bottom left
        let tailStart = CGPoint(x: rect.minX + 60, y: bubbleRect.maxY)
        let tailPeak = CGPoint(x: rect.minX + 50, y: rect.maxY)
        let tailEnd = CGPoint(x: rect.minX + 80, y: bubbleRect.maxY)

        path.move(to: tailStart)
        path.addQuadCurve(to: tailEnd, control: tailPeak)

        return path
    }
}

// MARK: - Summarize Shape (Document/Page)

/// Document-like shape with subtle page curl aesthetic
struct SummarizeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 20
        let topCurlSize: CGFloat = 30

        // Main document body
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))

        // Top edge with subtle curl on top-right
        path.addLine(to: CGPoint(x: rect.maxX - topCurlSize - cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topCurlSize),
            control: CGPoint(x: rect.maxX - topCurlSize / 2, y: rect.minY)
        )

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        return path
    }
}

// MARK: - Tone Feedback Shape (Balanced Scales)

/// Symmetrical shape representing balanced analysis
struct ToneFeedbackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 26
        let centerNotchDepth: CGFloat = 12
        let centerNotchWidth: CGFloat = 80

        // Start top-left
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))

        // Top edge to center notch
        path.addLine(to: CGPoint(x: rect.midX - centerNotchWidth / 2, y: rect.minY))

        // Center notch (scales pivot point)
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + centerNotchWidth / 2, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY - centerNotchDepth)
        )

        // Top edge to top-right
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        return path
    }
}

// MARK: - Chart Analysis Shape (Wide Landscape Viewport)

/// Wide, precision-focused rectangular shape with subtle curves
struct ChartAnalysisShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 16 // More angular for precision

        // Simple rounded rectangle with tighter corners
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        return path
    }
}

// MARK: - General Shape (Organic Blob/Capsule)

/// Soft, organic capsule shape for general purpose
struct GeneralShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 32 // Very rounded

        // Super-rounded rectangle (almost capsule-like)
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        return path
    }
}

// MARK: - Shape Type Erasure

/// Type-erased shape wrapper to allow dynamic shape selection
struct AnyShapeStyle: Shape, @unchecked Sendable {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Shape Factory

extension ModeVisualConfig {
    /// Returns the appropriate shape for this mode
    func shapeForMode() -> AnyShapeStyle {
        switch layoutStyle {
        case .splitPane:
            return AnyShapeStyle(CodeImprovementShape())
        case .floatingCards:
            return AnyShapeStyle(MessageReplyShape())
        case .verticalSections:
            return AnyShapeStyle(SummarizeShape())
        case .dualPanel:
            return AnyShapeStyle(ToneFeedbackShape())
        case .largeCanvas:
            return AnyShapeStyle(ChartAnalysisShape())
        case .flexible:
            return AnyShapeStyle(GeneralShape())
        }
    }
}
