import SwiftUI
import IRISCore
import IRISGaze
import IRISNetwork
import IRISMedia
import AppKit

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


struct OverlayView: View {
    @EnvironmentObject var coordinator: IRISCoordinator
    let screen: NSScreen // Screen this overlay belongs to

    // Debug flag - set to true to show debug overlays
    private let showDebugOverlays = false

    /// Adjust gaze point for display on each screen
    private func adjustedGazePoint(_ globalPoint: CGPoint) -> CGPoint {
        // Gaze is calibrated in the largest screen's coordinate space.
        // Scale to the current screen, then apply optional offsets for the calibration screen.
        let calibrationScreen = NSScreen.screens.max(by: { $0.frame.width < $1.frame.width }) ?? screen
        let calibrationSize = calibrationScreen.frame.size

        var adjusted = globalPoint

        if screen.frame.size != calibrationSize {
            let scaleX = screen.frame.width / calibrationSize.width
            let scaleY = screen.frame.height / calibrationSize.height
            adjusted = CGPoint(x: globalPoint.x * scaleX, y: globalPoint.y * scaleY)
        }

        if screen === calibrationScreen {
            let tuning = Self.externalTuning()
            adjusted.x += tuning.xOffset
            adjusted.y += tuning.yOffset

            // Apply optional per-axis gain around screen center (for external display only).
            let centerX = calibrationSize.width * 0.5
            let centerY = calibrationSize.height * 0.5
            adjusted.x = centerX + (adjusted.x - centerX) * tuning.xGain
            adjusted.y = centerY + (adjusted.y - centerY) * tuning.yGain
        }

        return adjusted
    }

    private struct ExternalTuning {
        var xOffset: CGFloat
        var yOffset: CGFloat
        var xGain: CGFloat
        var yGain: CGFloat
    }

    private static var tuningLastRead: Date = .distantPast
    private static var cachedTuning = ExternalTuning(xOffset: 0, yOffset: 700, xGain: 1.0, yGain: 1.0)

    private static func externalTuning() -> ExternalTuning {
        let now = Date()
        if now.timeIntervalSince(tuningLastRead) < 1.0 {
            return cachedTuning
        }
        tuningLastRead = now

        let path = "/tmp/iris_offsets.txt"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return cachedTuning
        }

        var x = cachedTuning.xOffset
        var y = cachedTuning.yOffset
        var xGain = cachedTuning.xGain
        var yGain = cachedTuning.yGain

        for rawLine in content.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count != 2 { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let valueStr = parts[1].trimmingCharacters(in: .whitespaces)
            guard let value = Double(valueStr) else { continue }
            switch key {
            case "external_x_offset":
                x = CGFloat(value)
            case "external_y_offset":
                y = CGFloat(value)
            case "external_x_gain":
                xGain = CGFloat(value)
            case "external_y_gain":
                yGain = CGFloat(value)
            default:
                break
            }
        }

        cachedTuning = ExternalTuning(xOffset: x, yOffset: y, xGain: xGain, yGain: yGain)
        return cachedTuning
    }

    var body: some View {
        ZStack {
            // Debug indicator removed per user request

            // Transparent background - never captures clicks
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(false)

            // Show gaze indicator (controlled only by user setting — never auto-hidden)
            if coordinator.showGazeIndicator {
                let modeConfig = ModeConfigurationFactory.config(for: "general")
                let displayPoint = adjustedGazePoint(coordinator.gazeEstimator.gazePoint)

                IRISFuturisticGazeIndicator(
                    gazePoint: displayPoint,
                    detectedElement: coordinator.gazeEstimator.detectedElement,
                    config: modeConfig.gazeIndicatorStyle,
                    screen: screen,
                    snapToElement: coordinator.snapIndicatorToElement,
                    voiceActive: coordinator.geminiAssistant.voiceAgentState == .userSpeaking
                )
                .allowsHitTesting(false)
            }

            if showDebugOverlays {
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
                .allowsHitTesting(false)
            }

            // Processing state indicator (only on active screen)
            if coordinator.geminiAssistant.isProcessing,
               coordinator.currentScreen === screen {
                let displayPoint = adjustedGazePoint(coordinator.gazeEstimator.gazePoint)
                ProcessingIndicator()
                    .position(x: displayPoint.x, y: displayPoint.y - 60)
                    .allowsHitTesting(false)
            }

            // Show intent results only on active screen
            if let intent = coordinator.lastIntent,
               coordinator.currentScreen === screen {
                IntentResultView(intent: intent)
                    .allowsHitTesting(false)
            }

            // New ethereal overlay based on working pattern
            // Don't set allowsHitTesting here - let internal views control it
            EtherealFloatingOverlay(geminiService: coordinator.geminiAssistant)

            if showDebugOverlays {
                VStack {
                    Spacer()
                    HStack {
                        DebugMini(coordinator: coordinator)
                        Spacer()
                    }
                    .padding(20)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // ENTIRE overlay never blocks clicks
    }
}

// MARK: - Voice Activity Debug Indicator

struct VoiceActivityIndicator: View {
    @ObservedObject var audioService: IRISMedia.AudioService
    @ObservedObject var geminiAssistant: GeminiAssistantOrchestrator

    @State private var pulseScale: CGFloat = 1.0

    private var statusColor: Color {
        if geminiAssistant.isListening {
            return .green
        } else if audioService.voiceActivityDetected {
            return .orange
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if geminiAssistant.isListening {
            return "LISTENING"
        } else if geminiAssistant.isProcessing {
            return "PROCESSING"
        } else if audioService.voiceActivityDetected {
            return "VOICE"
        } else {
            return "IDLE"
        }
    }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    // Audio level bar
                    GeometryReader { geo in
                        let barWidth = min(CGFloat(audioService.audioLevel) * 800, geo.size.width)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(statusColor.opacity(0.5))
                            .frame(width: barWidth, height: geo.size.height)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 40, height: 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(2)

                    // Status dot
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .scaleEffect(audioService.voiceActivityDetected ? pulseScale : 1.0)

                    // Status label
                    Text(statusText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Capsule()
                                .stroke(statusColor.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .onChange(of: audioService.voiceActivityDetected) { detected in
            if detected {
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    pulseScale = 1.4
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    pulseScale = 1.0
                }
            }
        }
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

struct IRISDashboardView: View {
    @EnvironmentObject var coordinator: IRISCoordinator
    @State private var orbRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.4
    @State private var ringRotation1: Double = 0
    @State private var ringRotation2: Double = 0
    @State private var appeared = false

    private var accentColor: Color {
        coordinator.isActive ? Color(hex: "00D4FF") : Color(hex: "6B7280")
    }

    var body: some View {
        ZStack {
            // Animated background
            animatedBackground

            VStack(spacing: 0) {
                Spacer()

                // Central orb + branding
                centralOrb
                    .padding(.bottom, 48)

                // Status pill
                statusPill
                    .padding(.bottom, 32)

                // Control cards row
                HStack(spacing: 20) {
                    trackingCard
                    intentCard
                }
                .padding(.horizontal, 60)

                Spacer()

                // Bottom bar
                bottomBar
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation1 = 360
            }
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                ringRotation2 = -360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
                glowIntensity = 0.7
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var animatedBackground: some View {
        ZStack {
            Color.black

            // Radial gradient from center
            RadialGradient(
                colors: [
                    accentColor.opacity(0.08),
                    Color.purple.opacity(0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 600
            )

            // Subtle grid pattern
            Canvas { context, size in
                let spacing: CGFloat = 60
                let color = Color.white.opacity(0.03)
                for x in stride(from: 0, to: size.width, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(color), lineWidth: 0.5)
                }
                for y in stride(from: 0, to: size.height, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(color), lineWidth: 0.5)
                }
            }

            // Top-left accent glow
            RadialGradient(
                colors: [Color(hex: "9333EA").opacity(0.06), Color.clear],
                center: UnitPoint(x: 0.15, y: 0.2),
                startRadius: 50,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Central Orb

    private var centralOrb: some View {
        ZStack {
            // Outer ring 1
            Circle()
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(ringRotation1))

            // Outer ring 2
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.4), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(ringRotation2))

            // Inner ring
            Circle()
                .trim(from: 0.2, to: 0.8)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "9333EA").opacity(0.3), accentColor.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [8, 4])
                )
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(ringRotation1 * 0.7))

            // Core glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(glowIntensity * 0.4), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(pulseScale)

            // Eye icon
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, Color(hex: "9333EA")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: accentColor.opacity(0.5), radius: 20)

            // Title below orb
            VStack(spacing: 4) {
                Spacer().frame(height: 110)
                Text("I . R . I . S")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(6)
                Text("Intelligent Responsive Iris System")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
            }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.8)
    }

    // MARK: - Status Pill

    private var statusPill: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(coordinator.isActive ? Color.green : Color.red.opacity(0.7))
                .frame(width: 8, height: 8)
                .shadow(color: coordinator.isActive ? Color.green.opacity(0.6) : Color.red.opacity(0.4), radius: 6)
                .scaleEffect(coordinator.isActive ? pulseScale : 1.0)

            Text(coordinator.isActive ? "TRACKING ACTIVE" : "TRACKING OFFLINE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(coordinator.isActive ? Color.green : Color.red.opacity(0.7))
                .tracking(2)

            if coordinator.isActive {
                Text("•")
                    .foregroundColor(.white.opacity(0.2))
                Text("GAZE \(Int(coordinator.gazeEstimator.gazePoint.x)),\(Int(coordinator.gazeEstimator.gazePoint.y))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.04))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Tracking Card

    private var trackingCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
                Text("TRACKING")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(2)
                Spacer()
            }

            Button {
                Task {
                    if coordinator.isActive {
                        coordinator.stop()
                    } else {
                        await coordinator.start()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: coordinator.isActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 16))
                    Text(coordinator.isActive ? "Stop Tracking" : "Start Tracking")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(coordinator.isActive ? .red : accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(coordinator.isActive ? Color.red.opacity(0.1) : accentColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(coordinator.isActive ? Color.red.opacity(0.2) : accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Toggles
            VStack(spacing: 10) {
                miniToggle(title: "GAZE INDICATOR", isOn: Binding(
                    get: { coordinator.showGazeIndicator },
                    set: { coordinator.showGazeIndicator = $0 }
                ))
                miniToggle(title: "SMART SNAP", isOn: Binding(
                    get: { coordinator.snapIndicatorToElement },
                    set: { coordinator.snapIndicatorToElement = $0 }
                ))
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(glassCard)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -30)
    }

    // MARK: - Intent Card

    private var intentCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "9333EA"))
                Text("LAST INTENT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(2)
                Spacer()
            }

            if let intent = coordinator.lastIntent {
                VStack(alignment: .leading, spacing: 8) {
                    Text(intent.action)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                    Text(intent.target)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(2)

                    // Confidence bar
                    HStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.06))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "9333EA"), accentColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * intent.confidence)
                            }
                        }
                        .frame(height: 4)

                        Text("\(Int(intent.confidence * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.15))
                    Text("No intent detected yet")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(glassCard)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 30)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Text("v1.0")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text("QUIT")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(.white.opacity(0.3))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Shared Components

    private var glassCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.03))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func miniToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1)
            Spacer()
            Button { isOn.wrappedValue.toggle() } label: {
                ZStack {
                    Capsule()
                        .fill(isOn.wrappedValue ? accentColor.opacity(0.25) : Color.white.opacity(0.06))
                        .frame(width: 34, height: 18)
                    Circle()
                        .fill(isOn.wrappedValue ? accentColor : Color.white.opacity(0.35))
                        .frame(width: 13, height: 13)
                        .offset(x: isOn.wrappedValue ? 8 : -8)
                        .shadow(color: isOn.wrappedValue ? accentColor.opacity(0.5) : .clear, radius: 4)
                }
                .animation(.spring(response: 0.3), value: isOn.wrappedValue)
            }
            .buttonStyle(.plain)
        }
    }
}

struct ContentView: View {
    var body: some View {
        EmptyView()
    }
}
