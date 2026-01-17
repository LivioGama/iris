import SwiftUI
import Combine

/// Coordinates smooth transitions between visual modes
/// Manages the transition state machine and timing
class ModeTransitionCoordinator: ObservableObject {
    @Published var currentMode: String = "general"
    @Published var transitionState: TransitionState = .stable
    @Published var transitionProgress: Double = 0.0

    private var transitionTimer: Timer?

    enum TransitionState {
        case stable              // No transition in progress
        case preparing           // Stage 1: Dimming current mode (0.1s)
        case transforming        // Stage 2: Morphing layout (0.5s)
        case settling            // Stage 3: Final bounce (0.2s)
    }

    // MARK: - Mode Transition

    /// Initiate transition to a new mode
    func transitionTo(mode: String, animated: Bool = true) {
        guard mode != currentMode else { return }

        if animated {
            performAnimatedTransition(to: mode)
        } else {
            currentMode = mode
            transitionState = .stable
            transitionProgress = 1.0
        }
    }

    // MARK: - Private Methods

    private func performAnimatedTransition(to newMode: String) {
        // Cancel any existing transition
        transitionTimer?.invalidate()

        // Stage 1: Preparation (0.1s)
        transitionState = .preparing
        transitionProgress = 0.0

        DispatchQueue.main.asyncAfter(deadline: .now() + IRISAnimations.transitionPreparation) { [weak self] in
            self?.continueTransition(to: newMode, fromStage: .preparing)
        }
    }

    private func continueTransition(to newMode: String, fromStage: TransitionState) {
        switch fromStage {
        case .preparing:
            // Stage 2: Transformation (0.5s)
            withAnimation(IRISAnimations.modeTransition) {
                transitionState = .transforming
                currentMode = newMode
                transitionProgress = 0.5
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + IRISAnimations.transitionTransformation) { [weak self] in
                self?.continueTransition(to: newMode, fromStage: .transforming)
            }

        case .transforming:
            // Stage 3: Settling (0.2s)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                transitionState = .settling
                transitionProgress = 0.9
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + IRISAnimations.transitionSettle) { [weak self] in
                self?.continueTransition(to: newMode, fromStage: .settling)
            }

        case .settling:
            // Complete
            withAnimation(.easeOut(duration: 0.1)) {
                transitionState = .stable
                transitionProgress = 1.0
            }

        case .stable:
            break
        }
    }

    // MARK: - Helpers

    /// Get the visual configuration for the current mode
    func getCurrentConfig() -> ModeVisualConfig {
        return ModeConfigurationFactory.config(for: currentMode)
    }

    /// Check if transition is in progress
    var isTransitioning: Bool {
        return transitionState != .stable
    }
}
