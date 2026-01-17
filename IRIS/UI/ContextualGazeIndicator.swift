import SwiftUI
import IRISCore

struct ContextualGazeIndicator: View {
    let gazePoint: CGPoint
    let detectedElement: DetectedElement?

    // Enable Metal rendering for maximum performance (120 FPS capable)
    // Set to false to use SwiftUI renderer (60 FPS)
    private let useMetalRenderer = true

    var body: some View {
        ZStack {
            if let element = detectedElement {
                DetectedElementView(element: element)
            }

            if useMetalRenderer {
                MetalGazeIndicatorView(gazePoint: gazePoint)
                    .allowsHitTesting(false)
            } else {
                OptimizedGazeIndicator(point: gazePoint)
            }
        }
    }
}

struct DetectedElementView: View {
    let element: DetectedElement

    var body: some View {
        ZStack {
            // Element rectangle highlight - filled background
            RoundedRectangle(cornerRadius: 6)
                .fill(elementTypeColor(for: element.type).opacity(0.15))
                .frame(width: element.bounds.width, height: element.bounds.height)
                .position(x: element.bounds.midX, y: element.bounds.midY)

            // Element rectangle highlight - stroke border
            RoundedRectangle(cornerRadius: 6)
                .stroke(elementTypeColor(for: element.type), lineWidth: 3)
                .frame(width: element.bounds.width, height: element.bounds.height)
                .position(x: element.bounds.midX, y: element.bounds.midY)

            // Element label above the rectangle
            ElementLabelView(element: element)
                .position(x: element.bounds.midX, y: element.bounds.minY - 20)
        }
    }

    private func elementTypeColor(for type: ElementType) -> Color {
        switch type {
        case .codeEditor:
            return .blue
        case .inputField:
            return .green
        case .sidebar:
            return .white
        case .panel:
            return .orange
        case .button:
            return .red
        case .textRegion:
            return .gray
        case .window:
            return .purple
        case .other:
            return .yellow
        }
    }
}

struct ElementLabelView: View {
    let element: DetectedElement

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background pill
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // Label text
                Text(element.label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .fixedSize()

            // Element type info
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                    )

                Text(typeDescription)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
            }
            .fixedSize()
        }
    }

    private var typeDescription: String {
        let typeStr = String(describing: element.type)
        let size = "\(Int(element.bounds.width))×\(Int(element.bounds.height))"
        let conf = "\(Int(element.confidence * 100))%"
        return "\(typeStr) | \(size) | \(conf)"
    }
}

struct SimpleGazeIndicator: View {
    let point: CGPoint

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                .frame(width: 100, height: 100)

            Circle()
                .stroke(Color.cyan, lineWidth: 3)
                .frame(width: 60, height: 60)

            Circle()
                .fill(Color.cyan.opacity(0.2))
                .frame(width: 60, height: 60)

            Circle()
                .fill(Color.cyan)
                .frame(width: 10, height: 10)
        }
        .position(point)
    }
}

struct AnalyzingIndicator: View {
    @State private var rotation = 0.0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.blue.opacity(0.6), lineWidth: 3)
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
