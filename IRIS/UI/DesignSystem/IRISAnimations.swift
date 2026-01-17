import SwiftUI

/// IRIS Design System - Animations
/// Defines timing curves, spring configurations, and animation patterns
enum IRISAnimations {

    // MARK: - Duration Constants

    /// Instant feedback (0.15s) - UI interactions, hover states
    static let instant: Double = 0.15

    /// Quick transitions (0.3s) - Element appearances, micro-interactions
    static let quick: Double = 0.3

    /// Standard animations (0.5s) - Layout changes, content swaps
    static let standard: Double = 0.5

    /// Smooth transitions (0.8s) - Mode transitions, major layout changes
    static let smooth: Double = 0.8

    /// Slow reveals (1.2s) - Dramatic entrances, special emphasis
    static let slow: Double = 1.2

    // MARK: - Spring Configurations

    /// Bouncy spring - Playful modes (messageReply, general)
    /// Response: 0.5, Damping: 0.7
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.7)

    /// Snappy spring - Precise modes (codeImprovement, chartAnalysis)
    /// Response: 0.3, Damping: 0.85
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.85)

    /// Smooth spring - Calm modes (summarize, toneFeedback)
    /// Response: 0.6, Damping: 0.9
    static let smoothSpring = Animation.spring(response: 0.6, dampingFraction: 0.9)

    // MARK: - Easing Curves

    /// Ease out - Natural deceleration
    static let easeOut = Animation.easeOut(duration: standard)

    /// Ease in - Natural acceleration
    static let easeIn = Animation.easeIn(duration: standard)

    /// Ease in-out - Smooth acceleration and deceleration
    static let easeInOut = Animation.easeInOut(duration: standard)

    /// Linear - Constant speed (for rotations, progress indicators)
    static let linear = Animation.linear(duration: standard)

    // MARK: - Mode-Specific Animations

    /// Get spring animation for specific mode
    static func springForMode(_ mode: String) -> Animation {
        switch mode.lowercased() {
        case "messagereply", "general":
            return bouncy
        case "codeimprovement", "chartanalysis":
            return snappy
        case "summarize", "tonefeedback":
            return smoothSpring
        default:
            return smoothSpring
        }
    }

    // MARK: - Specialized Animation Patterns

    /// Staggered delay for sequential animations (e.g., cards appearing)
    static func staggerDelay(index: Int, baseDelay: Double = 0.1) -> Double {
        return Double(index) * baseDelay
    }

    /// Pulse animation (for emphasis, loading states)
    static let pulse = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)

    /// Gentle glow (for hover states, selection)
    static let glow = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)

    /// Rotation (for spinners, processing indicators)
    static let rotation = Animation.linear(duration: 0.8).repeatForever(autoreverses: false)

    /// Scale pulse (for loading dots)
    static let scalePulse = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)

    // MARK: - Mode Transition Timings

    /// Stage 1: Preparation phase (0.1s)
    static let transitionPreparation: Double = 0.1

    /// Stage 2: Transformation phase (0.5s)
    static let transitionTransformation: Double = 0.5

    /// Stage 3: Settle phase (0.2s)
    static let transitionSettle: Double = 0.2

    /// Total mode transition duration
    static let transitionTotal: Double = 0.8

    /// Mode transition animation
    static let modeTransition = Animation.spring(response: 0.6, dampingFraction: 0.85)
}

// MARK: - Animation View Modifiers

extension View {
    /// Apply bouncy spring animation
    func bouncyAnimation() -> some View {
        self.animation(IRISAnimations.bouncy, value: UUID())
    }

    /// Apply snappy spring animation
    func snappyAnimation() -> some View {
        self.animation(IRISAnimations.snappy, value: UUID())
    }

    /// Apply smooth spring animation
    func smoothAnimation() -> some View {
        self.animation(IRISAnimations.smoothSpring, value: UUID())
    }

    /// Apply mode-specific animation
    func modeAnimation(_ mode: String) -> some View {
        self.animation(IRISAnimations.springForMode(mode), value: UUID())
    }
}

// MARK: - Transition Effects

enum IRISTransitions {
    /// Fade transition
    static let fade = AnyTransition.opacity

    /// Slide from top
    static let slideFromTop = AnyTransition.move(edge: .top).combined(with: .opacity)

    /// Slide from bottom
    static let slideFromBottom = AnyTransition.move(edge: .bottom).combined(with: .opacity)

    /// Slide from left
    static let slideFromLeft = AnyTransition.move(edge: .leading).combined(with: .opacity)

    /// Slide from right
    static let slideFromRight = AnyTransition.move(edge: .trailing).combined(with: .opacity)

    /// Scale transition (zoom in/out)
    static let scale = AnyTransition.scale.combined(with: .opacity)

    /// Float up (for cards, message bubbles)
    static let floatUp = AnyTransition.asymmetric(
        insertion: AnyTransition.offset(y: 30).combined(with: .opacity),
        removal: .opacity
    )

    /// Morph (for mode transitions)
    static let morph = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.95).combined(with: .opacity),
        removal: .scale(scale: 1.05).combined(with: .opacity)
    )
}

// MARK: - Keyframe Animation Helpers

struct IRISKeyframeAnimations {
    /// Code block entrance (split-pane slide in)
    static func codeBlockEntrance(isAfter: Bool) -> AnyTransition {
        let edge: Edge = isAfter ? .trailing : .leading
        return AnyTransition.asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Message card entrance with stagger
    static func messageCardEntrance(index: Int) -> Animation {
        Animation.spring(response: 0.5, dampingFraction: 0.7)
            .delay(IRISAnimations.staggerDelay(index: index, baseDelay: 0.1))
    }

    /// Section reveal (for summarize mode)
    static func sectionReveal(index: Int) -> Animation {
        Animation.easeOut(duration: 0.4)
            .delay(IRISAnimations.staggerDelay(index: index, baseDelay: 0.15))
    }
}
