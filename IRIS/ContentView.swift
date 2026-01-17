import SwiftUI
import IRISCore
import IRISGaze
import IRISNetwork

struct OverlayView: View {
    @EnvironmentObject var coordinator: IRISCoordinator

    var body: some View {
        ZStack {
            Color.clear

            // Hide indicator when Gemini overlay is active
            let isGeminiActive = coordinator.geminiAssistant.isListening ||
                                coordinator.geminiAssistant.isProcessing ||
                                !coordinator.geminiAssistant.chatMessages.isEmpty

            if coordinator.gazeEstimator.isTrackingEnabled && !isGeminiActive {
                ContextualGazeIndicator(
                    gazePoint: coordinator.gazeEstimator.gazePoint,
                    detectedElement: coordinator.gazeEstimator.detectedElement
                )
            }

            VStack {
                Text(coordinator.gazeDebugInfo)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(12)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(10)

                Spacer()
            }
            .padding(.top, 50)

            if coordinator.currentState == .processing {
                ProcessingIndicator()
                    .position(x: coordinator.gazeEstimator.gazePoint.x, y: coordinator.gazeEstimator.gazePoint.y - 60)
            }

            if let intent = coordinator.lastIntent {
                IntentResultView(intent: intent)
            }

            GeminiResponseOverlay(geminiService: coordinator.geminiAssistant)

            VStack {
                Spacer()
                HStack {
                    DebugMini(coordinator: coordinator)
                    Spacer()
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GazeIndicator: View {
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

struct CalibrationTarget: View {
    let corner: CalibrationCorner
    @State private var scale = 1.0

    var body: some View {
        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 100

        let position: CGPoint = {
            switch corner {
            case .topLeft: return CGPoint(x: margin, y: margin)
            case .topRight: return CGPoint(x: screen.width - margin, y: margin)
            case .bottomLeft: return CGPoint(x: margin, y: screen.height - margin)
            case .bottomRight: return CGPoint(x: screen.width - margin, y: screen.height - margin)
            case .center: return CGPoint(x: screen.width / 2, y: screen.height / 2)
            default: return CGPoint(x: screen.width / 2, y: screen.height / 2)
            }
        }()

        ZStack {
            Circle()
                .fill(Color.red.opacity(0.4))
                .frame(width: 120, height: 120)
                .scaleEffect(scale)

            Circle()
                .fill(Color.red)
                .frame(width: 30, height: 30)

            Text("LOOK HERE")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .offset(y: 50)
        }
        .position(position)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                scale = 1.4
            }
        }
    }
}

struct ProcessingIndicator: View {
    @State private var rotation = 0.0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.orange, lineWidth: 4)
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct IntentResultView: View {
    let intent: ResolvedIntent
    @State private var opacity = 1.0

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(intent.action)
                    .font(.system(size: 16, weight: .semibold))
            }

            Text(intent.target)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(Double(i) / 5.0 < intent.confidence ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                Text("\(Int(intent.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
        )
        .foregroundColor(.white)
        .position(x: NSScreen.main?.frame.width ?? 800 / 2, y: 80)
        .opacity(opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0
                }
            }
        }
    }
}

struct DebugMini: View {
    @ObservedObject var coordinator: IRISCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(coordinator.isActive ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("I.R.I.S")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            Text("Gaze: \(Int(coordinator.gazeEstimator.gazePoint.x)), \(Int(coordinator.gazeEstimator.gazePoint.y))")
                .font(.system(size: 10, design: .monospaced))

            Text("State: \(String(describing: coordinator.currentState))")
                .font(.system(size: 10, design: .monospaced))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
        .foregroundColor(.white.opacity(0.9))
    }
}

struct MenuBarView: View {
    @EnvironmentObject var coordinator: IRISCoordinator

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(coordinator.isActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(coordinator.isActive ? "Active" : "Inactive")
                    .font(.headline)
            }

            Button(coordinator.isActive ? "Stop Tracking" : "Start Tracking") {
                Task {
                    if coordinator.isActive {
                        coordinator.stop()
                    } else {
                        await coordinator.start()
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            Divider()

            if let intent = coordinator.lastIntent {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Intent:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(intent.action)
                        .font(.caption)
                    Text(intent.target)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
}

struct ContentView: View {
    var body: some View {
        EmptyView()
    }
}
