import SwiftUI

/// Adaptive Gaze Indicator - Mode-aware visual indicator
/// Changes color and animation based on current mode
struct AdaptiveGazeIndicator: View {
    let gazePoint: CGPoint
    let config: GazeIndicatorConfig
    @State private var animationPhase: CGFloat = 0.0

    var body: some View {
        ZStack {
            // Concentric rings (fade outward)
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(config.color.opacity(ringOpacity(for: index)), lineWidth: 2)
                    .frame(width: ringSize(for: index), height: ringSize(for: index))
            }

            // Center dot
            Circle()
                .fill(config.color)
                .frame(width: 10, height: 10)
        }
        .scaleEffect(config.size.scale)
        .position(gazePoint)
        .onAppear {
            startAnimation()
        }
        .onChange(of: config.animationStyle) { _ in
            startAnimation()
        }
    }

    // MARK: - Ring Calculations

    private func ringSize(for index: Int) -> CGFloat {
        let baseSize: CGFloat = 30
        let spacing: CGFloat = 15
        let animationOffset = animationOffsetFor(index)
        return (baseSize + CGFloat(index) * spacing) * animationOffset
    }

    private func ringOpacity(for index: Int) -> Double {
        let baseOpacity = 0.6 - (Double(index) * 0.2)

        switch config.animationStyle {
        case .glow:
            return baseOpacity * (0.5 + animationPhase * 0.5)
        case .pulse:
            return baseOpacity * (index == 0 ? (0.6 + animationPhase * 0.4) : baseOpacity)
        case .ripple:
            let ripplePhase = (animationPhase + CGFloat(index) * 0.3).truncatingRemainder(dividingBy: 1.0)
            return baseOpacity * (1.0 - ripplePhase)
        default:
            return baseOpacity
        }
    }

    private func animationOffsetFor(_ index: Int) -> CGFloat {
        switch config.animationStyle {
        case .snap:
            return 1.0 // No animation, precise
        case .pulse:
            return index == 0 ? (1.0 + animationPhase * 0.1) : 1.0
        case .glow:
            return 1.0 + animationPhase * 0.05
        case .ripple:
            let ripplePhase = (animationPhase + CGFloat(index) * 0.3).truncatingRemainder(dividingBy: 1.0)
            return 1.0 + ripplePhase * 0.2
        case .minimal:
            return 0.8 // Smaller, subtler
        case .steady:
            return 1.0
        }
    }

    // MARK: - Animation Control

    private func startAnimation() {
        // Reset animation phase
        animationPhase = 0.0

        switch config.animationStyle {
        case .pulse:
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animationPhase = 1.0
            }

        case .glow:
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animationPhase = 1.0
            }

        case .ripple:
            withAnimation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                animationPhase = 1.0
            }

        case .snap, .steady, .minimal:
            // No continuous animation
            animationPhase = 0.0
        }
    }
}

// MARK: - Preview

struct AdaptiveGazeIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black

            VStack(spacing: 40) {
                // Code Improvement - Pulse
                AdaptiveGazeIndicator(
                    gazePoint: CGPoint(x: 150, y: 100),
                    config: GazeIndicatorConfig(
                        color: IRISColors.codeImprovementAccent,
                        animationStyle: .pulse,
                        size: .standard
                    )
                )

                // Message Reply - Glow
                AdaptiveGazeIndicator(
                    gazePoint: CGPoint(x: 150, y: 200),
                    config: GazeIndicatorConfig(
                        color: IRISColors.messageReplyAccent,
                        animationStyle: .glow,
                        size: .large
                    )
                )

                // Summarize - Steady
                AdaptiveGazeIndicator(
                    gazePoint: CGPoint(x: 150, y: 300),
                    config: GazeIndicatorConfig(
                        color: IRISColors.summarizeAccent,
                        animationStyle: .steady,
                        size: .standard
                    )
                )

                // Tone Feedback - Ripple
                AdaptiveGazeIndicator(
                    gazePoint: CGPoint(x: 150, y: 400),
                    config: GazeIndicatorConfig(
                        color: IRISColors.toneFeedbackAccent,
                        animationStyle: .ripple,
                        size: .standard
                    )
                )

                // Chart Analysis - Snap
                AdaptiveGazeIndicator(
                    gazePoint: CGPoint(x: 150, y: 500),
                    config: GazeIndicatorConfig(
                        color: IRISColors.chartAnalysisAccent,
                        animationStyle: .snap,
                        size: .precision
                    )
                )

                // General - Minimal
                AdaptiveGazeIndicator(
                    gazePoint: CGPoint(x: 150, y: 600),
                    config: GazeIndicatorConfig(
                        color: IRISColors.generalAccent,
                        animationStyle: .minimal,
                        size: .small
                    )
                )
            }
        }
        .frame(width: 300, height: 700)
    }
}
