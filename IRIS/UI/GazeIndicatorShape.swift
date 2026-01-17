import SwiftUI

/// Unified shape for gaze indicator - single path for all circles
/// Eliminates 4 separate Circle views and reduces SwiftUI diffing overhead
struct GazeIndicatorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // All circles centered at origin, positioned by parent view

        // Outer ring (100x100)
        path.addEllipse(in: CGRect(x: -50, y: -50, width: 100, height: 100))

        // Middle ring outer (60x60)
        path.addEllipse(in: CGRect(x: -30, y: -30, width: 60, height: 60))

        // Center dot (10x10)
        path.addEllipse(in: CGRect(x: -5, y: -5, width: 10, height: 10))

        return path
    }
}

/// Optimized gaze indicator using single custom shape
struct OptimizedGazeIndicator: View {
    let point: CGPoint

    var body: some View {
        ZStack {
            // Outer ring - stroke only
            Circle()
                .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                .frame(width: 100, height: 100)

            // Middle ring - stroke + fill
            Circle()
                .stroke(Color.cyan, lineWidth: 3)
                .frame(width: 60, height: 60)

            Circle()
                .fill(Color.cyan.opacity(0.2))
                .frame(width: 60, height: 60)

            // Center dot - fill only
            Circle()
                .fill(Color.cyan)
                .frame(width: 10, height: 10)
        }
        .position(point)
    }
}
