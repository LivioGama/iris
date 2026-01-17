//
//  EtherealFloatingOverlay.swift
//  IRIS
//
//  Ethereal floating overlay - screenshot slides up, AI presence flows below
//

import SwiftUI
import IRISCore
import IRISNetwork
import AppKit

// MARK: - Demo Control Panel View (Separate Clickable Window)

/// Standalone demo control panel with spatial liquid glass aesthetic
struct DemoControlPanelView: View {
    @EnvironmentObject var coordinator: IRISCoordinator
    @State private var selectedIndex: Int = 0
    @State private var customPrompt: String = "how can I improve this code?"
    @State private var isSending: Bool = false
    @State private var isHovering: Bool = false

    private let demoSchemas = DynamicUIDemoGenerator.allDemoSchemas()

    var body: some View {
        VStack(spacing: 0) {
            // Floating title pill
            titleSection
                .padding(.bottom, 16)

            // Gemini test card
            geminiTestSection
                .padding(.bottom, 12)

            // Templates grid
            templatesSection

            Spacer(minLength: 12)

            // Close button
            closeButton
        }
        .padding(20)
        .background(spatialGlassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(glassStroke)
        .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
        .shadow(color: Color.cyan.opacity(0.1), radius: 20, x: 0, y: 5)
    }

    // MARK: - Spatial Glass Background

    private var spatialGlassBackground: some View {
        ZStack {
            // Deep background with noise texture feel
            Color.black.opacity(0.6)

            // Frosted glass material
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)

            // Gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.cyan.opacity(0.03),
                    Color.purple.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle inner glow
            RadialGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 300
            )
        }
    }

    private var glassStroke: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    // MARK: - Subviews

    private var titleSection: some View {
        HStack(spacing: 8) {
            // Animated dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan, Color.cyan.opacity(0.5)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 8, height: 8)
                .shadow(color: Color.cyan.opacity(0.6), radius: 4, x: 0, y: 0)

            Text("DEMO MODE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .tracking(1.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var geminiTestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.cyan)
                Text("TEST WITH GEMINI")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan.opacity(0.9))
                    .tracking(0.5)
            }

            promptTextField
            quickPromptButtons
            sendButton
        }
        .padding(14)
        .background(glassCard(tint: .cyan))
    }

    private var promptTextField: some View {
        TextField("Enter prompt...", text: $customPrompt)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .foregroundColor(.white)
    }

    private var quickPromptButtons: some View {
        let prompts = ["improve code", "explain this", "find bugs", "better way"]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(prompts, id: \.self) { prompt in
                    quickPromptButton(prompt)
                }
            }
        }
    }

    private func quickPromptButton(_ prompt: String) -> some View {
        let isSelected = customPrompt == prompt
        return Button(action: { customPrompt = prompt }) {
            Text(prompt)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.cyan.opacity(0.25) : Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .foregroundColor(isSelected ? .cyan : .white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    private var sendButton: some View {
        Button(action: { sendPromptToGemini() }) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(-45))
                }
                Text(isSending ? "Sending..." : "Send to Gemini")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(sendButtonBackground)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSending || customPrompt.isEmpty)
        .opacity(customPrompt.isEmpty ? 0.5 : 1)
    }

    private var sendButtonBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: isSending
                    ? [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]
                    : [Color.cyan.opacity(0.4), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Shimmer overlay
            if !isSending {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.purple)
                Text("TEMPLATES")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.purple.opacity(0.9))
                    .tracking(0.5)
            }

            // Grid of template cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(demoSchemas.enumerated()), id: \.offset) { index, schema in
                    templateCard(index: index, schema: schema)
                }
            }
        }
        .padding(14)
        .background(glassCard(tint: .purple))
    }

    private func templateCard(index: Int, schema: DynamicUISchema) -> some View {
        let isSelected = selectedIndex == index && coordinator.geminiAssistant.isOverlayVisible
        let accentColor = Color(hex: schema.theme.accentColor)

        return Button(action: {
            selectedIndex = index
            coordinator.geminiAssistant.dynamicUISchema = schema
            coordinator.geminiAssistant.isOverlayVisible = true
        }) {
            VStack(spacing: 6) {
                // Icon with glow
                Text(schema.theme.icon ?? "📄")
                    .font(.system(size: 20))
                    .shadow(color: isSelected ? accentColor.opacity(0.6) : Color.clear, radius: 8, x: 0, y: 0)

                // Title
                Text(schema.theme.title ?? "Template")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 1 : 0.5
                            )
                    )
            )
            .shadow(color: isSelected ? accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var closeButton: some View {
        Button(action: {
            coordinator.geminiAssistant.dynamicUISchema = nil
            coordinator.geminiAssistant.isOverlayVisible = false
            coordinator.geminiAssistant.resetConversationState()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                Text("Close")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Views

    private func glassCard(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.08), tint.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.3), tint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }

    private func sendPromptToGemini() {
        guard !customPrompt.isEmpty else { return }
        isSending = true

        Task {
            // Capture screenshot using the screen capture service
            let screenshot = await captureCurrentScreen()

            guard let screenshot = screenshot else {
                await MainActor.run {
                    isSending = false
                }
                return
            }

            // Set the captured screenshot
            await MainActor.run {
                coordinator.geminiAssistant.capturedScreenshot = screenshot
                coordinator.geminiAssistant.chatMessages.append(
                    ChatMessage(role: .user, content: customPrompt, timestamp: Date())
                )
            }

            // Send to Gemini
            await coordinator.geminiAssistant.sendToGeminiForDemo(
                screenshot: screenshot,
                prompt: customPrompt
            )

            await MainActor.run {
                isSending = false
            }
        }
    }

    private func captureCurrentScreen() async -> NSImage? {
        // Determine which screen the cursor is on
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main

        guard let screen = screen else { return nil }

        // Use CGWindowListCreateImage to capture the screen
        let screenRect = screen.frame

        print("📸 Capturing screen at cursor location: \(screen.localizedName)")

        guard let cgImage = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else { return nil }

        return NSImage(cgImage: cgImage, size: screenRect.size)
    }
}

// MARK: - Authentic Gemini Star Shape

/// Custom shape that creates the authentic Gemini 4-pointed star
/// Based on curved bezier paths between four points
struct GeminiStarShape: Shape {
    /// Determines how "sharp" the star is (0.65-0.7 for authentic Gemini look)
    var sharpness: CGFloat = 0.68

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let top    = CGPoint(x: rect.midX, y: rect.minY)
        let right  = CGPoint(x: rect.maxX, y: rect.midY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let left   = CGPoint(x: rect.minX, y: rect.midY)

        // Control points for smooth curves
        let controlTopRight    = interpolatedPoint(from: CGPoint(x: rect.maxX, y: rect.minY), to: center, t: sharpness)
        let controlBottomRight = interpolatedPoint(from: CGPoint(x: rect.maxX, y: rect.maxY), to: center, t: sharpness)
        let controlBottomLeft  = interpolatedPoint(from: CGPoint(x: rect.minX, y: rect.maxY), to: center, t: sharpness)
        let controlTopLeft     = interpolatedPoint(from: CGPoint(x: rect.minX, y: rect.minY), to: center, t: sharpness)

        path.move(to: top)
        path.addQuadCurve(to: right, control: controlTopRight)
        path.addQuadCurve(to: bottom, control: controlBottomRight)
        path.addQuadCurve(to: left, control: controlBottomLeft)
        path.addQuadCurve(to: top, control: controlTopLeft)
        path.closeSubpath()

        return path
    }

    private func interpolatedPoint(from start: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let x = start.x + (end.x - start.x) * t
        let y = start.y + (end.y - start.y) * t
        return CGPoint(x: x, y: y)
    }
}

/// Ethereal floating overlay - screenshot slides up, gradient AI presence, floating dream text
struct EtherealFloatingOverlay: View {
    @ObservedObject var geminiService: GeminiAssistantOrchestrator
    @State private var screenshotOffset: CGFloat = 0
    @State private var showGradient: Bool = false

    // Scroll-to-dismiss state
    @State private var accumulatedScrollY: CGFloat = 0
    @State private var dismissAnimationOffset: CGFloat = 0  // Only used for dismiss animation
    @State private var isDismissing: Bool = false
    @State private var scrollMonitor: Any? = nil
    @State private var keyboardMonitor: Any? = nil
    @State private var scrollResetTimer: Timer? = nil
    private let dismissThreshold: CGFloat = -80  // Accumulated scroll up threshold

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                if isOverlayActive || isDismissing {
                    etherealContent(geometry: geometry)
                        .offset(y: dismissAnimationOffset)
                        .opacity(isDismissing ? max(0.0, 1.0 - Double(abs(dismissAnimationOffset)) / 300.0) : 1.0)
                        .animation(.easeOut(duration: 0.3), value: dismissAnimationOffset)
                        .onAppear {
                            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                screenshotOffset = -50
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeIn(duration: 0.6)) {
                                    showGradient = true
                                }
                            }
                            startScrollMonitor()
                        }
                        .onDisappear {
                            screenshotOffset = 0
                            showGradient = false
                            accumulatedScrollY = 0
                            isDismissing = false
                            stopScrollMonitor()
                        }
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            // Status console ALWAYS visible at bottom (outside overlay check)
            VStack {
                Spacer()
                statusConsole
            }
            .allowsHitTesting(false)
        }
        .onChange(of: isOverlayActive) { active in
            if active {
                startScrollMonitor()
            } else {
                stopScrollMonitor()
            }
        }
    }



    // MARK: - Scroll Monitor for Dismiss Gesture

    private func startScrollMonitor() {
        // Remove existing monitor if any
        stopScrollMonitor()

        // Add global monitor for scroll wheel events
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [self] event in
            handleScrollEvent(event)
        }

        // Add global monitor for keyboard events:
        // - Escape: dismiss overlay
        // - Fn/Globe: immediately stop model speech
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [self] event in
            handleKeyboardEvent(event)
        }

        print("🖱️ Scroll monitor started for dismiss gesture")
        print("⌨️ Keyboard monitor started for Escape dismiss + Fn speech interrupt")
    }

    private func stopScrollMonitor() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
            print("🖱️ Scroll monitor stopped")
        }
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
            print("⌨️ Keyboard monitor stopped")
        }
        scrollResetTimer?.invalidate()
        scrollResetTimer = nil
    }

    private func handleScrollEvent(_ event: NSEvent) {
        // Only process if overlay is active
        guard isOverlayActive && !isDismissing else { return }

        // scrollingDeltaY: negative = scroll up (natural scrolling)
        let deltaY = event.scrollingDeltaY

        // Only accumulate upward scrolls (negative delta)
        if deltaY < 0 {
            accumulatedScrollY += deltaY

            // Reset timer - if user stops scrolling, reset accumulation
            scrollResetTimer?.invalidate()
            scrollResetTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [self] _ in
                accumulatedScrollY = 0
            }

            // Check if threshold reached
            if accumulatedScrollY < dismissThreshold {
                triggerDismiss()
            }
        }
    }

    private func handleKeyboardEvent(_ event: NSEvent) {
        // Only process if overlay is active
        guard isOverlayActive && !isDismissing else { return }

        // Fn / Globe key (flagsChanged keyCode 63) interrupts model speech instantly.
        if event.type == .flagsChanged,
           event.keyCode == 63,
           event.modifierFlags.contains(.function) {
            print("⌨️ Fn/Globe pressed - interrupting model speech")
            Task { @MainActor in
                geminiService.interruptModelSpeech()
            }
            return
        }

        // Check for Escape key (keyCode 53)
        if event.keyCode == 53 {
            print("⌨️ Escape key pressed - dismissing overlay")
            triggerDismiss()
        }
    }

    private func triggerDismiss() {
        guard !isDismissing else { return }

        print("🖱️ Scroll dismiss triggered!")
        isDismissing = true
        stopScrollMonitor()

        // Animate slide up and fade out
        dismissAnimationOffset = -300

        // Reset state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            geminiService.resetConversationState()
            // Reset animation state AFTER conversation state is cleared
            DispatchQueue.main.async {
                isDismissing = false
                dismissAnimationOffset = 0
                accumulatedScrollY = 0
            }
        }
    }

    // CRITICAL: Same condition as working overlay - also check for demo mode with schema and proactive suggestions
    private var isOverlayActive: Bool {
        geminiService.isListening || geminiService.isProcessing ||
        !geminiService.chatMessages.isEmpty || geminiService.capturedScreenshot != nil ||
        !geminiService.liveTranscription.isEmpty ||
        !geminiService.liveGeminiResponse.isEmpty ||
        !geminiService.proactiveSuggestions.isEmpty ||
        (geminiService.demoAllTemplates && geminiService.dynamicUISchema != nil)
    }

    // MARK: - Ethereal Content

    @ViewBuilder
    private func etherealContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Screenshot and Conversation contents
            etherealMainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Console (transparent terminal log at bottom)

    @ViewBuilder
    private var statusConsole: some View {
        let isLive = geminiService.isLiveSessionActive
        let state = geminiService.voiceAgentState

        // Only show mic indicator — no technical logs on screen
        if isLive {
            HStack(spacing: 4) {
                Circle()
                    .fill(state == .userSpeaking ? Color.green : (state == .modelSpeaking ? Color.blue : Color.white.opacity(0.4)))
                    .frame(width: 5, height: 5)
                Text(state == .userSpeaking ? "listening..." : (state == .modelSpeaking ? "speaking..." : "mic open"))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var etherealMainContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Screenshot pinned at top
                if let screenshot = geminiService.capturedScreenshot {
                    VStack {
                        screenshotView(screenshot)
                            .offset(y: screenshotOffset)
                            .padding(.top, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }

                // Main conversation layout — top-aligned, centered
                VStack(spacing: 0) {
                    // History messages — top aligned
                    conversationHistoryView
                        .padding(.top, 8)

                    // Live input bar - now at top of active conversation
                    liveInputBar
                        .padding(.vertical, 2)

                    // AI response area - appears below user input
                    liveResponseArea

                    Spacer()

                    // Proactive suggestions & execution UI
                    statusOverlays
                        .padding(.horizontal, 60)

                    listeningHint
                        .padding(.horizontal, 60)
                        .padding(.bottom, 20)
                }

                // Small discrete Gemini indicator — top left
                if geminiService.isProcessing || geminiService.voiceAgentState == .modelSpeaking {
                    smallGeminiIndicator
                        .padding(.top, 16)
                        .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Small Discrete Gemini Indicator (top-left)

    @ViewBuilder
    private var smallGeminiIndicator: some View {
        HStack(spacing: 6) {
            // Tiny animated Gemini star
            GeminiStarShape(sharpness: 0.68)
                .fill(
                    LinearGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.8),
                            IRISProductionColors.geminiPurple.opacity(0.6),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 14, height: 14)
                .shadow(color: IRISProductionColors.geminiBlue.opacity(0.5), radius: 6, x: 0, y: 0)
                .scaleEffect(geminiService.isProcessing ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: geminiService.isProcessing)

            // Subtle pulsing dots
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(IRISProductionColors.geminiPurple.opacity(0.6))
                        .frame(width: 3, height: 3)
                        .scaleEffect(geminiService.isProcessing ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                            value: geminiService.isProcessing
                        )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Capsule()
                        .stroke(IRISProductionColors.geminiBlue.opacity(0.15), lineWidth: 0.5)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
        .animation(.easeInOut(duration: 0.3), value: geminiService.isProcessing)
    }

    // MARK: - Conversation History (scrolls upward from center)

    @ViewBuilder
    private var conversationHistoryView: some View {
        let recentMessages = Array(geminiService.chatMessages.suffix(6))
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                      (($0.role == .assistant) ? !Self.filterTechnicalText($0.content).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : true) }

        if !recentMessages.isEmpty {
            VStack(spacing: 12) {
                ForEach(Array(recentMessages.enumerated()), id: \.element.id) { index, message in
                    let total = recentMessages.count
                    let age = total - index - 1
                    let fadeOpacity = age <= 1 ? 1.0 : max(0.15, 1.0 - Double(age - 1) * 0.4)

                    Group {
                        if message.role == .user {
                            userInputBubble(text: message.content, isLive: false)
                        } else {
                            geminiResponseBubble(text: Self.filterTechnicalText(message.content), isStreaming: false)
                        }
                    }
                    .opacity(fadeOpacity)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
                    .id(message.id)
                }
            }
            .padding(.horizontal, 60)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Live Input Bar (always at screen center)

    @ViewBuilder
    private var liveInputBar: some View {
        if !geminiService.liveTranscription.isEmpty {
            userInputBubble(text: geminiService.liveTranscription, isLive: true)
                .padding(.horizontal, 60)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: geminiService.liveTranscription)
        } else if geminiService.isListening && geminiService.chatMessages.isEmpty && geminiService.capturedScreenshot != nil {
            // Subtle listening indicator when no transcript yet
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(IRISProductionColors.geminiBlue.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .scaleEffect(geminiService.voiceAgentState == .userSpeaking ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                            value: geminiService.voiceAgentState
                        )
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Live Response Area (below center, slides up)

    @ViewBuilder
    private var liveResponseArea: some View {
        let filteredLiveResponse = Self.filterTechnicalText(geminiService.liveGeminiResponse)

        if !filteredLiveResponse.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        geminiResponseBubble(text: filteredLiveResponse, isStreaming: true)
                            .id("liveResponse")

                        Color.clear.frame(height: 1).id("responseBottom")
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 12)
                }
                .onChange(of: geminiService.liveGeminiResponse) { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        proxy.scrollTo("responseBottom", anchor: .bottom)
                    }
                }
            }
            .allowsHitTesting(false)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity
            ))
        }
    }

    @ViewBuilder
    private var statusOverlays: some View {
        // Proactive Suggestions (Live Mode)
        if !geminiService.proactiveSuggestions.isEmpty {
            ProactiveSuggestionsView(
                suggestions: geminiService.proactiveSuggestions,
                context: geminiService.detectedContext,
                onSelect: { suggestion in
                    Task {
                        await geminiService.executeProactiveSuggestion(suggestion)
                    }
                },
                onCustomRequest: {
                    geminiService.voiceAgentState = .userSpeaking
                }
            )
            .frame(maxWidth: 500)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .id("proactiveSuggestions")
        }

        // Execution confirmation UI
        if geminiService.showExecutionConfirmation,
           let plan = geminiService.pendingActionPlan {
            ExecutionConfirmationView(
                plan: plan,
                skill: geminiService.currentMatchedSkill,
                onConfirm: {
                    geminiService.confirmExecution()
                },
                onCancel: {
                    geminiService.cancelExecution()
                }
            )
            .frame(maxWidth: 400)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .id("executionConfirmation")
        }

        // Execution progress indicator
        if geminiService.isExecutingSkill && !geminiService.executionProgress.isEmpty {
            ExecutionProgressView(
                progress: geminiService.executionProgress,
                isExecuting: geminiService.isExecutingSkill
            )
            .frame(maxWidth: 400)
            .transition(.opacity)
            .id("executionProgress")
        }
    }

    @ViewBuilder
    private var listeningHint: some View {
        if geminiService.capturedScreenshot != nil &&
           geminiService.liveTranscription.isEmpty &&
           !geminiService.isProcessing &&
           geminiService.chatMessages.isEmpty &&
           !geminiService.isAnalyzingScreenshot &&
           geminiService.proactiveSuggestions.isEmpty {
            Text("speak now")
                .font(.system(size: 12, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .tracking(4)
        }
    }

    @ViewBuilder
    private func geminiResponseWithDividers(message: ChatMessage) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)

            geminiDivider(colors: [IRISProductionColors.geminiBlue.opacity(0.5), IRISProductionColors.geminiPurple.opacity(0.5)])

            Spacer().frame(height: 30)

            if let schema = geminiService.dynamicUISchema,
               !schema.components.isEmpty,
               geminiService.useDynamicUI {
                DynamicUIRenderer(
                    schema: schema,
                    screenshot: geminiService.capturedScreenshot,
                    onAction: { action in
                        handleDynamicUIAction(action)
                    }
                )
                .frame(maxWidth: schema.layout.maxWidth ?? 900)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                geminiResponseBubble(text: message.content, isStreaming: false)
            }

            Spacer().frame(height: 30)

            geminiDivider(colors: [IRISProductionColors.geminiPurple.opacity(0.5), IRISProductionColors.geminiBlue.opacity(0.5)])

            Spacer().frame(height: 30)
        }
    }

    @ViewBuilder
    private func geminiDivider(colors: [Color]) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .frame(width: 400, height: 1)
            .shadow(color: colors[0].opacity(0.6), radius: 4)
    }

    // MARK: - Components

    @ViewBuilder
    private var bigGeminiStar: some View {
        if geminiService.isProcessing {
            // Siri-like animated blob during processing
            animatedGeminiOrb
        } else {
            // Static 4-pointed star during listening/idle
            staticGeminiStar
        }
    }

    // Static 4-pointed Gemini star (for listening state)
    @ViewBuilder
    private var staticGeminiStar: some View {
        ZStack {
            // Outer glow layer
            GeminiStarShape(sharpness: 0.68)
                .fill(
                    LinearGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.15),
                            IRISProductionColors.geminiPurple.opacity(0.12),
                            IRISProductionColors.geminiPink.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 800, height: 800)
                .blur(radius: 60)
                .opacity(0.4)

            // Mid layer
            GeminiStarShape(sharpness: 0.68)
                .fill(
                    LinearGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.25),
                            IRISProductionColors.geminiPurple.opacity(0.2),
                            IRISProductionColors.geminiPink.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 35)

            // Sharp inner layer
            GeminiStarShape(sharpness: 0.68)
                .fill(
                    LinearGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.35),
                            IRISProductionColors.geminiPurple.opacity(0.28),
                            IRISProductionColors.geminiPink.opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 450, height: 450)
                .blur(radius: 18)

            // Ultra-sharp core
            GeminiStarShape(sharpness: 0.68)
                .fill(
                    LinearGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.45),
                            IRISProductionColors.geminiPurple.opacity(0.35),
                            IRISProductionColors.geminiPink.opacity(0.2),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 350, height: 350)
                .blur(radius: 8)

            // Center bright core
            GeminiStarShape(sharpness: 0.68)
                .fill(
                    RadialGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.5),
                            IRISProductionColors.geminiPurple.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 5)
        }
    }

    // Animated Siri-like blob (for processing state)
    @ViewBuilder
    private var animatedGeminiOrb: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius: CGFloat = 180

                // Calculate fluid motion
                let flowSpeed: Double = 1.5
                let t = time * flowSpeed

                // 3D perspective values
                let tiltAmount: Double = 25.0
                let perspectiveX = sin(t * 0.7) * tiltAmount
                let perspectiveY = cos(t * 0.5) * tiltAmount

                // Draw multiple flowing layers for depth
                for layerIndex in (0..<7).reversed() {
                    let layerProgress = CGFloat(layerIndex) / 6.0
                    let layerRadius = baseRadius * (0.4 + layerProgress * 0.9)

                    // Each layer has different morph timing for organic feel
                    let morphOffset = Double(layerIndex) * 0.4
                    let morph1 = sin(t * 1.1 + morphOffset) * 0.15
                    let morph2 = cos(t * 0.9 + morphOffset) * 0.12
                    let morph3 = sin(t * 1.4 + morphOffset * 1.5) * 0.1

                    // Create blobby path with sine wave distortions
                    var path = Path()
                    let segments = 64
                    for i in 0...segments {
                        let angle = (Double(i) / Double(segments)) * .pi * 2

                        // Multiple sine waves for organic blob shape
                        let wave1 = sin(angle * 3 + t * 2) * morph1
                        let wave2 = cos(angle * 5 + t * 1.5) * morph2
                        let wave3 = sin(angle * 7 + t * 2.5) * morph3
                        let radiusVariation = 1.0 + wave1 + wave2 + wave3

                        // Add energy wave
                        let energyPulse = sin(angle * 2 - t * 4) * 0.05 * (1 - layerProgress)

                        let r = layerRadius * CGFloat(radiusVariation + energyPulse)

                        // Apply 3D perspective distortion
                        let perspectiveScale = 1.0 + sin(angle + perspectiveX * 0.02) * 0.15
                        let x = center.x + cos(angle) * r * perspectiveScale
                        let yBase = center.y + sin(angle) * r * perspectiveScale

                        // Add depth compression for 3D effect
                        let depthFactor = 1.0 + cos(angle) * sin(perspectiveY * 0.02) * 0.15
                        let y = center.y + (yBase - center.y) * depthFactor

                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.closeSubpath()

                    // Color flow - Gemini palette with smooth transitions
                    let colorPhase = t * 0.8 + Double(layerIndex) * 0.5

                    // Base colors: blue (#4796E3), purple (#9177C7), pink (#CA6673)
                    let blueAmount = (sin(colorPhase) + 1) / 2
                    let purpleAmount = (sin(colorPhase + .pi * 0.66) + 1) / 2
                    let pinkAmount = (sin(colorPhase + .pi * 1.33) + 1) / 2

                    let r = 0.28 * blueAmount + 0.57 * purpleAmount + 0.79 * pinkAmount
                    let g = 0.59 * blueAmount + 0.47 * purpleAmount + 0.40 * pinkAmount
                    let b = 0.89 * blueAmount + 0.78 * purpleAmount + 0.45 * pinkAmount

                    // Opacity based on layer depth
                    let layerOpacity = 0.6 * (0.3 + layerProgress * 0.7)

                    // Inner glow boost
                    let glowBoost = layerIndex < 2 ? 0.3 : 0.0

                    context.fill(
                        path,
                        with: .color(Color(
                            red: min(1, r + glowBoost),
                            green: min(1, g + glowBoost * 0.8),
                            blue: min(1, b + glowBoost * 0.5)
                        ).opacity(layerOpacity))
                    )

                    // Add blur effect for outer layers
                    if layerIndex > 4 {
                        context.blendMode = .plusLighter
                        context.fill(
                            path,
                            with: .color(Color(red: r, green: g, blue: b).opacity(layerOpacity * 0.3))
                        )
                        context.blendMode = .normal
                    }
                }

                // Bright core
                let coreRadius = baseRadius * 0.25
                let corePulse = 1.0 + sin(t * 3) * 0.1
                let corePath = Path(ellipseIn: CGRect(
                    x: center.x - coreRadius * corePulse,
                    y: center.y - coreRadius * corePulse,
                    width: coreRadius * 2 * corePulse,
                    height: coreRadius * 2 * corePulse
                ))

                context.fill(
                    corePath,
                    with: .radialGradient(
                        Gradient(colors: [
                            .white.opacity(0.9),
                            IRISProductionColors.geminiBlue.opacity(0.6),
                            IRISProductionColors.geminiPurple.opacity(0.3),
                            .clear
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: coreRadius * corePulse
                    )
                )
            }
            .blur(radius: 8)
            .overlay {
                // Sharp inner detail layer
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let baseRadius: CGFloat = 140
                    let t = time * 1.8

                    var path = Path()
                    let segments = 48
                    for i in 0...segments {
                        let angle = (Double(i) / Double(segments)) * .pi * 2
                        let wave = sin(angle * 4 + t * 2.5) * 0.12
                        let wave2 = cos(angle * 6 + t * 1.8) * 0.08
                        let r = baseRadius * CGFloat(1.0 + wave + wave2)

                        let x = center.x + cos(angle) * r
                        let y = center.y + sin(angle) * r

                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.closeSubpath()

                    let colorT = t * 0.6
                    context.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                IRISProductionColors.geminiBlue.opacity(0.5),
                                IRISProductionColors.geminiPurple.opacity(0.45),
                                IRISProductionColors.geminiPink.opacity(0.4)
                            ]),
                            startPoint: CGPoint(
                                x: center.x + cos(colorT) * 100,
                                y: center.y + sin(colorT) * 100
                            ),
                            endPoint: CGPoint(
                                x: center.x - cos(colorT) * 100,
                                y: center.y - sin(colorT) * 100
                            )
                        )
                    )
                }
                .blur(radius: 3)
            }
            // 3D rotation transforms
            .rotation3DEffect(
                .degrees(sin(time * 0.7) * 20),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.4
            )
            .rotation3DEffect(
                .degrees(cos(time * 0.5) * 25),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.4
            )
            .rotation3DEffect(
                .degrees(sin(time * 0.4) * 10),
                axis: (x: 0, y: 0, z: 1),
                perspective: 0.5
            )
            // Breathing scale
            .scaleEffect(1.0 + CGFloat(sin(time * 2.0)) * 0.08)
        }
        .frame(width: 1200, height: 1200)
        .drawingGroup(opaque: false)
    }

    // MARK: - Analyzing Indicator (Proactive Mode)

    @ViewBuilder
    private var analyzingIndicator: some View {
        VStack(spacing: 16) {
            // Animated dots with Gemini colors
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [IRISProductionColors.geminiBlue, IRISProductionColors.geminiPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 10, height: 10)
                        .scaleEffect(1.2)
                        .opacity(0.8)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: UUID()
                        )
                }
            }

            Text("Analyzing...")
                .font(.system(size: 14, weight: .light, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)

            // Invite user to speak while analyzing
            Text("or speak now")
                .font(.system(size: 12, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)
        }
        .padding(.vertical, 20)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    @ViewBuilder
    private func toolExecutionIndicator(_ tool: (name: String, args: [String: Any])) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text("Executing Action")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))

                Text(formatToolDisplay(tool))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.purple.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private func formatToolDisplay(_ tool: (name: String, args: [String: Any])) -> String {
        switch tool.name {
        case "click_at":
            if let x = tool.args["x"] as? Double, let y = tool.args["y"] as? Double {
                return "Click at (\(Int(x)), \(Int(y)))"
            }
        case "type_text":
            if let text = tool.args["text"] as? String {
                let prefix = String(text.prefix(20))
                return "Type \"\(prefix)\(text.count > 20 ? "..." : "")\""
            }
        case "press_key":
             if let key = tool.args["key"] as? String {
                 return "Press Key: \(key)"
             }
        case "run_terminal_command":
             if let cmd = tool.args["command"] as? String {
                 let prefix = String(cmd.prefix(30))
                 return "Run: \(prefix)..."
             }
        case "open_app":
             if let name = tool.args["name"] as? String {
                 return "Open: \(name)"
             }
        default:
            return tool.name
        }
        return tool.name
    }

    private func userInputBubble(text: String, isLive: Bool) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .tracking(0.3)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        // Frosted glass base
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                        // Tinted overlay
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.cyan.opacity(0.15))
                        // Subtle border
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 0.5)
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
                .frame(maxWidth: 500)
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }

    @ViewBuilder
    private func geminiResponseBubble(text: String, isStreaming: Bool) -> some View {
        let filtered = Self.filterTechnicalText(text)

        HStack {
            Spacer()
            Text(filtered)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .tracking(0.3)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        // Frosted glass base
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                        // Tinted overlay
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.purple.opacity(0.15))
                        // Subtle border
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 0.5)
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
                .frame(maxWidth: 500)
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }

    private func isCodeImprovementResponse(at index: Int) -> Bool {
        guard geminiService.currentIntent == .codeImprovement,
              let parsedResponse = geminiService.parsedICOIResponse,
              parsedResponse.hasCodeComparison else {
            return false
        }

        let lastAssistantIndex = geminiService.chatMessages.lastIndex { $0.role == .assistant }
        return lastAssistantIndex == index
    }

    @ViewBuilder
    private func codeImprovementBubble(_ parsedResponse: ICOIParsedResponse) -> some View {
        CodeComparisonView(
            oldCode: parsedResponse.oldCode ?? "",
            newCode: parsedResponse.newCode ?? "",
            language: parsedResponse.codeLanguage ?? "Code",
            improvements: parsedResponse.improvements,
            onCopyNew: { copyToClipboard(parsedResponse.newCode ?? "") }
        )
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    /// Strips technical/debug/thinking lines from model output before display.
    /// Keeps only user-facing text. Debug info goes to /tmp/iris_live_debug.log.
    static func filterTechnicalText(_ text: String) -> String {
        let technicalPrefixes: [String] = [
            "🔧", "📤", "📥", "🔄", "✅ GeminiLive", "❌ Gemini", "⚠️ Gemini",
            "📹", "🎤 VAD", "🔊 Sending", "🔇 Model", "💡 Proactive",
            "Tool call", "Received TOOL", "Setup keys", "Session started",
            "DEBUG:", "LOG:", "TRACE:", "ERROR:", "WARNING:",
            "function_call", "tool_response", "serverContent",
        ]
        let technicalContains: [String] = [
            "tool_call", "function_response", "setupComplete",
            "base64", "jpegBase64", "pcm16",
        ]
        let lines = text.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return false }
            // Filter bold markdown reasoning headers like **Confirming The Action**
            if trimmed.hasPrefix("**") && trimmed.contains("**") { return false }
            // Filter lines that are just model internal reasoning
            if trimmed.hasPrefix("I'm ") || trimmed.hasPrefix("I've ") || trimmed.hasPrefix("I am ") { return false }
            for prefix in technicalPrefixes {
                if trimmed.hasPrefix(prefix) { return false }
            }
            for keyword in technicalContains {
                if trimmed.contains(keyword) { return false }
            }
            return true
        }
        let result = filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "" : result
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Handles actions from the dynamic UI components
    private func handleDynamicUIAction(_ action: UIAction) {
        switch action.type {
        case .copy:
            if let payload = action.payload {
                copyToClipboard(payload)
            }
        case .dismiss:
            geminiService.resetConversationState()
        case .speak:
            // TTS could be implemented here
            if let payload = action.payload {
                print("🔊 TTS requested: \(payload)")
            }
        case .select:
            // Handle option selection
            if let payload = action.payload {
                print("✅ Option selected: \(payload)")
            }
        case .navigate:
            // Open URL
            if let payload = action.payload, let url = URL(string: payload) {
                NSWorkspace.shared.open(url)
            }
        case .expand, .custom:
            // These are handled internally by DynamicUIRenderer
            break
        }
    }

    @ViewBuilder
    private func screenshotView(_ screenshot: NSImage) -> some View {
        // Screenshot display only - overlay is fully pass-through
        // Use keyboard shortcut or voice command to dismiss
        Image(nsImage: screenshot)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 400, maxHeight: 200)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var gradientAIPresence: some View {
        // Gradient presence - Gemini sparkle/star shape
        // Using official Gemini colors: #4796E3 (blue), #9177C7 (purple), #CA6673 (red/pink)
        VStack {
            Spacer()
                .frame(height: 180)

            ZStack {
                // Four-pointed star/sparkle shape like Gemini logo
                ForEach(0..<4, id: \.self) { i in
                    let angle = Double(i) * 90.0

                    // Each ray of the sparkle
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    IRISProductionColors.geminiBlue.opacity(0.3),                                    IRISProductionColors.geminiPurple.opacity(0.2),                                    IRISProductionColors.geminiPink.opacity(0.08),                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 60, height: 180)
                        .blur(radius: 30)
                        .rotationEffect(.degrees(angle))
                        .scaleEffect(showGradient ? 1.15 : 0.95)
                        .opacity(showGradient ? 0.9 : 0.6)
                }

                // Smaller inner sparkle for depth (rotated 45 degrees)
                ForEach(0..<4, id: \.self) { i in
                    let angle = Double(i) * 90.0 + 45.0

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    IRISProductionColors.geminiPurple.opacity(0.25),                                    IRISProductionColors.geminiBlue.opacity(0.12),                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 40, height: 120)
                        .blur(radius: 25)
                        .rotationEffect(.degrees(angle))
                        .scaleEffect(showGradient ? 0.95 : 1.15)
                        .opacity(showGradient ? 0.7 : 0.4)
                }

                // Center glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                IRISProductionColors.geminiBlue.opacity(0.2),
                                IRISProductionColors.geminiPurple.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                    .scaleEffect(showGradient ? 1.2 : 1.0)
            }
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: showGradient)
            .mask(
                RadialGradient(
                    colors: [
                        .black,
                        .black,
                        .black.opacity(0.8),
                        .black.opacity(0.4),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 280
                )
            )

            Spacer()
        }
    }



    @ViewBuilder
    private var floatingTranscription: some View {
        VStack(spacing: 20) {
            // ALWAYS show user input at the top (NEVER disappears)
            if !geminiService.liveTranscription.isEmpty {
                // Live transcription while speaking
                Text(geminiService.liveTranscription)
                    .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, IRISProductionColors.geminiBlue.opacity(0.9)],                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(1)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)
                    .shadow(color: IRISProductionColors.geminiBlue.opacity(0.3), radius: 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
            } else if let lastUserMessage = geminiService.chatMessages.last(where: { $0.role == .user }) {
                // Show last user message (stays visible during processing and streaming)
                Text(lastUserMessage.content)
                    .font(.system(size: 24, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), IRISProductionColors.geminiBlue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(0.8)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)
                    .shadow(color: IRISProductionColors.geminiBlue.opacity(0.25), radius: 15)
                    .zIndex(100)
            } else if !geminiService.transcribedText.isEmpty {
                // Fallback: show transcribed text if available
                Text(geminiService.transcribedText)
                    .font(.system(size: 24, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), IRISProductionColors.geminiBlue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(0.8)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)
                    .shadow(color: IRISProductionColors.geminiBlue.opacity(0.25), radius: 15)
                    .zIndex(100)
            }

            // Layer waves and messages with ZStack
            ZStack(alignment: .top) {
                // Animated gradient waves BELOW messages (always in background)
                if geminiService.isProcessing && geminiService.liveGeminiResponse.isEmpty {
                    animatedGradientWaves
                        .zIndex(0)  // Background
                }

                // Chat conversation - only assistant messages, max 3 visible (in front)
                if !geminiService.chatMessages.isEmpty || !geminiService.liveGeminiResponse.isEmpty {
                    assistantMessagesView
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .zIndex(10)  // Foreground
                }
            }

            // Subtle listening hint
            if geminiService.capturedScreenshot != nil && geminiService.liveTranscription.isEmpty && !geminiService.isProcessing && geminiService.chatMessages.isEmpty {
                Text("speak now")
                    .font(.system(size: 12, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(4)
                    .opacity(0.6)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: UUID())
            }
        }
    }

    // MARK: - Animated Gradient Waves

    @ViewBuilder
    private var animatedGradientWaves: some View {
        ZStack {
            // Multiple overlapping gradient layers with 3D wave animations
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                IRISProductionColors.geminiBlue.opacity(0.2),                                IRISProductionColors.geminiPurple.opacity(0.15),                                IRISProductionColors.geminiPink.opacity(0.1),                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 150)
                    .blur(radius: 35 + CGFloat(i * 5))
                    .scaleEffect(
                        x: showGradient ? 1.3 + Double(i) * 0.1 : 0.9 - Double(i) * 0.05,
                        y: showGradient ? 0.8 - Double(i) * 0.05 : 1.2 + Double(i) * 0.1
                    )
                    .offset(
                        x: showGradient ? CGFloat(30 - i * 15) : CGFloat(-30 + i * 15),
                        y: CGFloat(i * 20)
                    )
                    .rotationEffect(.degrees(showGradient ? Double(i * 3) : Double(-i * 3)))
                    .opacity(showGradient ? 0.9 : 0.5)
                    .animation(
                        .easeInOut(duration: 3.5 + Double(i) * 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.25),
                        value: showGradient
                    )
            }
        }
        .frame(width: 800, height: 400)
        // Removed .clipped() - it was cutting off the blur/glow effects
        .drawingGroup(opaque: false)  // Better performance for complex animations
        .transition(.opacity)
    }

    // MARK: - Assistant Messages View (Max 3)

    @ViewBuilder
    private var assistantMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Only show assistant messages, max 3
                    let assistantMessages = geminiService.chatMessages.filter { $0.role == .assistant }
                    let recentMessages = Array(assistantMessages.suffix(3))

                    ForEach(Array(recentMessages.enumerated()), id: \.element.id) { index, message in
                        let isOldest = index == 0
                        let isMiddle = index == 1

                        // Fade and move up older messages
                        let opacity = isOldest ? 0.3 : (isMiddle ? 0.6 : 1.0)
                        let yOffset = isOldest ? -20.0 : (isMiddle ? -10.0 : 0.0)

                        dreamChatBubble(message)
                            .opacity(opacity)
                            .offset(y: yOffset)
                            .transition(.opacity.combined(with: .move(edge: .top).combined(with: .scale(scale: 0.95))))
                            .animation(.easeOut(duration: 0.8), value: recentMessages.count)
                            .id(message.id)
                    }

                    // Live streaming response
                    if !geminiService.liveGeminiResponse.isEmpty {
                        let filteredLive = EtherealFloatingOverlay.filterTechnicalText(geminiService.liveGeminiResponse)
                        if !filteredLive.isEmpty {
                            VStack(spacing: 8) {
                                Text(filteredLive)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.92))
                                    .tracking(0.2)
                                    .lineSpacing(5)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(red: 0.3, green: 0.1, blue: 0.5).opacity(0.8))
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 5)

                                // Streaming indicator
                                HStack(spacing: 4) {
                                    ForEach(0..<3, id: \.self) { i in
                                        Circle()
                                            .fill(Color.purple.opacity(0.8))
                                            .frame(width: 4, height: 4)
                                            .scaleEffect(1.2)
                                            .animation(
                                                .easeInOut(duration: 0.6)
                                                    .repeatForever(autoreverses: true)
                                                    .delay(Double(i) * 0.2),
                                                value: UUID()
                                            )
                                    }
                                }
                            }
                            .frame(maxWidth: 550)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .id("streaming")
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .frame(maxHeight: 400)
            .onChange(of: geminiService.chatMessages.count) { _ in
                // Smooth scroll to latest message
                if let lastMessage = geminiService.chatMessages.last {
                    withAnimation(.easeOut(duration: 0.4)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: geminiService.liveGeminiResponse) { _ in
                // Follow streaming response
                if !geminiService.liveGeminiResponse.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Chat Conversation View (OLD - UNUSED)

    @ViewBuilder
    private var chatConversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Previous chat messages with fade effect
                    ForEach(Array(geminiService.chatMessages.enumerated()), id: \.element.id) { index, message in
                        let isRecent = index >= geminiService.chatMessages.count - 3
                        let opacity = isRecent ? 1.0 : max(0.3, 1.0 - Double(geminiService.chatMessages.count - index) * 0.15)

                        dreamChatBubble(message)
                            .opacity(opacity)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .id(message.id)
                    }

                    // Live streaming response - centered
                    if !geminiService.liveGeminiResponse.isEmpty {
                        VStack(spacing: 12) {
                            Text(geminiService.liveGeminiResponse)
                                .font(.system(size: 20, weight: .light, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, IRISProductionColors.geminiPurple],                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .tracking(0.4)
                                .lineSpacing(8)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(red: 0.3, green: 0.1, blue: 0.5).opacity(0.8))
                                        .blur(radius: 8)
                                )
                                .shadow(color: Color.purple.opacity(0.4), radius: 15)

                            // Streaming indicator
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(Color.purple.opacity(0.8))
                                        .frame(width: 4, height: 4)
                                        .scaleEffect(1.2)
                                        .animation(
                                            .easeInOut(duration: 0.6)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(i) * 0.2),
                                            value: UUID()
                                        )
                                }
                            }
                        }
                        .frame(maxWidth: 700)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .id("streaming")
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .frame(maxHeight: 500)
            .mask(
                // Fade gradient at top to fade messages below screenshot
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.3),
                        .black,
                        .black
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.15)
                )
            )
            .onChange(of: geminiService.chatMessages.count) { _ in
                // Smooth scroll to latest message
                if let lastMessage = geminiService.chatMessages.last {
                    withAnimation(.easeOut(duration: 0.4)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: geminiService.liveGeminiResponse) { _ in
                // Follow streaming response
                if !geminiService.liveGeminiResponse.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dreamChatBubble(_ message: ChatMessage) -> some View {
        let displayText = message.role == .assistant
            ? EtherealFloatingOverlay.filterTechnicalText(message.content)
            : message.content

        return VStack(spacing: 4) {
            Text(displayText)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .tracking(0.2)
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(message.role == .user ? Color.cyan.opacity(0.15) : Color.purple.opacity(0.15))
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(message.role == .user ? Color.cyan.opacity(0.3) : Color.purple.opacity(0.3), lineWidth: 0.5)
                    }
                )
                .shadow(color: .black.opacity(0.4), radius: 5)
        }
        .frame(maxWidth: 550)
    }

    @ViewBuilder
    private var presenceIndicator_OLD: some View {
        HStack(spacing: 16) {
            // Pulsing consciousness dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.9), Color.cyan.opacity(0.2)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .frame(width: 12, height: 12)
                .shadow(color: Color.cyan.opacity(0.5), radius: 8)
                .scaleEffect(geminiService.isListening || geminiService.isProcessing ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: UUID())

            // Minimal status text
            if geminiService.isListening {
                Text("listening")
                    .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(2)
            } else if geminiService.isProcessing {
                Text("thinking")
                    .font(.system(size: 11, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.purple.opacity(0.7))
                    .tracking(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
    }

    @ViewBuilder
    private var mainVisualization: some View {
        VStack(spacing: 24) {
            // Show screenshot captured indicator
            if geminiService.capturedScreenshot != nil && !geminiService.isListening && !geminiService.isProcessing {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.cyan.opacity(0.6))

                    Text("Screenshot captured")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.8))

                    Text("Speak now to analyze")
                        .font(.system(size: 14, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                }
                .padding(40)
                .transition(.opacity.combined(with: .scale))
            }

            // Static Gemini star when listening (no audio waves)
            if geminiService.isListening {
                bigGeminiStar
                    .frame(width: 200, height: 200)
                    .transition(.opacity.combined(with: .scale))

                // Live transcription
                if !geminiService.liveTranscription.isEmpty {
                    Text(geminiService.liveTranscription)
                        .font(.system(size: 22, weight: .thin, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(0.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 700)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }
            }

            // Processing indicator
            if geminiService.isProcessing {
                thinkingDots
                    .transition(.opacity.combined(with: .scale))

                // Live response
                if !geminiService.liveGeminiResponse.isEmpty {
                    Text(geminiService.liveGeminiResponse)
                        .font(.system(size: 20, weight: .thin, design: .rounded))
                        .foregroundColor(.purple.opacity(0.9))
                        .tracking(0.5)
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 700)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }
            }

            // Chat messages
            if !geminiService.chatMessages.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(geminiService.chatMessages) { message in
                            chatBubble(message)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: 800, maxHeight: 400)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: geminiService.isListening)
        .animation(.easeInOut(duration: 0.4), value: geminiService.isProcessing)
    }

    @ViewBuilder
    private var audioWaves: some View {
        HStack(spacing: 4) {
            ForEach(0..<24, id: \.self) { index in
                waveBar(index: index)
            }
        }
        .frame(height: 80)
    }

    @ViewBuilder
    private func waveBar(index: Int) -> some View {
        let height = CGFloat.random(in: 8...60)
        let delay = Double(index) * 0.04

        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.8),
                        Color.blue.opacity(0.5),
                        Color.cyan.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3, height: height)
            .opacity(0.7)
            .animation(
                .easeInOut(duration: Double.random(in: 1.0...2.0))
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: height
            )
    }

    @ViewBuilder
    private var thinkingDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.purple.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.2)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: UUID()
                    )
            }
        }
    }

    @ViewBuilder
    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            Text(message.content)
                .font(.system(size: 16, weight: .light, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(message.role == .user ? Color.cyan.opacity(0.2) : Color.purple.opacity(0.2))
                )
                .frame(maxWidth: 600, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        if geminiService.capturedScreenshot != nil && !geminiService.isListening && !geminiService.isProcessing {
            Text("speak to continue")
                .font(.system(size: 10, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .tracking(3)
        }
    }
}

// MARK: - Markdown Response View

/// Parses markdown text and renders code blocks with proper styling
struct MarkdownResponseView: View {
    let text: String
    let accentColor: String
    let secondaryColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(parseMarkdown().enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    textView(content)
                case .codeBlock(let code, let language):
                    codeBlockView(code: code, language: language)
                case .inlineCode(let code):
                    inlineCodeView(code)
                case .header(let level, let text):
                    headerView(level: level, text: text)
                case .listItem(let text):
                    listItemView(text: text)
                case .paragraph(let attributed):
                    paragraphView(attributed: attributed)
                }
            }
        }
    }

    // MARK: - Text View

    @ViewBuilder
    private func textView(_ content: String) -> some View {
        Text(content)
            .font(.system(size: 17, weight: .medium, design: .rounded))  // Increased from 14 regular to 17 medium
            .foregroundColor(.white.opacity(0.95))  // Increased from 0.92
            .tracking(0.3)  // Increased from 0.2
            .lineSpacing(7)  // Increased from 5
            .multilineTextAlignment(.leading)
            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)  // Stronger shadow
    }

    // MARK: - Code Block View

    @ViewBuilder
    private func codeBlockView(code: String, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language tag
            if let lang = language, !lang.isEmpty {
                HStack {
                    Text(lang.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(Color(hex: accentColor).opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(hex: accentColor).opacity(0.15))
                                .overlay(Capsule().stroke(Color(hex: accentColor).opacity(0.3), lineWidth: 0.5))
                        )

                    Spacer()

                    // Copy button
                    Button(action: { copyToClipboard(code) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
            }

            // Code content
            ScrollView(.horizontal, showsIndicators: true) {  // Enable scroll indicators
                Text(code)
                    .font(.system(size: 15, weight: .regular, design: .monospaced))  // Increased from 13
                    .foregroundColor(.white.opacity(0.95))
                    .textSelection(.enabled)
                    .padding(14)  // Increased from 12
            }
            .frame(maxHeight: 400)  // Increased from 300
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: accentColor).opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    // MARK: - Inline Code View

    @ViewBuilder
    private func inlineCodeView(_ code: String) -> some View {
        Text(code)
            .font(.system(size: 16, weight: .semibold, design: .monospaced))  // Increased from 14 medium to 16 semibold
            .foregroundColor(Color(hex: accentColor))
            .padding(.horizontal, 8)  // Increased from 6
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: accentColor).opacity(0.15))
            )
    }

    // MARK: - Header View

    @ViewBuilder
    private func headerView(level: Int, text: String) -> some View {
        let fontSize: CGFloat = {
            switch level {
            case 1: return 24  // Increased from 18
            case 2: return 21  // Increased from 16
            case 3: return 19  // Increased from 15
            default: return 17  // Increased from 14
            }
        }()

        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: accentColor), .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .tracking(0.5)
            .shadow(color: .black.opacity(0.7), radius: 5, x: 0, y: 2)
            .shadow(color: Color(hex: accentColor).opacity(0.4), radius: 15)
            .padding(.top, level == 1 ? 8 : 4)
    }

    // MARK: - List Item View

    @ViewBuilder
    private func listItemView(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {  // Increased spacing from 6
            Circle()
                .fill(Color(hex: accentColor))
                .frame(width: 6, height: 6)  // Increased from 4x4
                .padding(.top, 7)  // Adjusted from 6

            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))  // Increased from 13 regular to 16 medium
                .foregroundColor(.white.opacity(0.95))  // Increased from 0.92
                .tracking(0.3)  // Increased from 0.2
                .lineSpacing(4)
        }
        .padding(.leading, 6)
    }

    // MARK: - Paragraph View

    @ViewBuilder
    private func paragraphView(attributed: AttributedString) -> some View {
        Text(attributed)
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.92))
            .tracking(0.2)
            .lineSpacing(5)
            .multilineTextAlignment(.leading)
            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
    }

    // MARK: - Parsing

    private enum MarkdownSegment {
        case text(String)
        case codeBlock(code: String, language: String?)
        case inlineCode(String)
        case header(level: Int, text: String)
        case listItem(text: String)
        case paragraph(AttributedString)
    }

    private func parseMarkdown() -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        var remaining = text

        // Pattern for fenced code blocks: ```language\ncode\n```
        let codeBlockPattern = "```(\\w*)\\n([\\s\\S]*?)```"

        while !remaining.isEmpty {
            if let regex = try? NSRegularExpression(pattern: codeBlockPattern),
               let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {

                // Get text before the code block and parse it for markdown
                if let beforeRange = Range(NSRange(location: 0, length: match.range.location), in: remaining) {
                    let beforeText = String(remaining[beforeRange])
                    segments.append(contentsOf: parseTextSegment(beforeText))
                }

                // Extract language and code
                let language: String?
                if let langRange = Range(match.range(at: 1), in: remaining) {
                    let lang = String(remaining[langRange])
                    language = lang.isEmpty ? nil : lang
                } else {
                    language = nil
                }

                if let codeRange = Range(match.range(at: 2), in: remaining) {
                    let code = String(remaining[codeRange]).trimmingCharacters(in: .newlines)
                    segments.append(.codeBlock(code: code, language: language))
                }

                // Move past this match
                if let fullRange = Range(match.range, in: remaining) {
                    remaining = String(remaining[fullRange.upperBound...])
                } else {
                    break
                }
            } else {
                // No more code blocks, parse remaining text for markdown
                segments.append(contentsOf: parseTextSegment(remaining))
                break
            }
        }

        // If no segments were found, return the whole text
        if segments.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(contentsOf: parseTextSegment(text))
        }

        return segments
    }

    private func parseTextSegment(_ text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check for headers (# Header)
            if trimmed.hasPrefix("#") {
                if let headerRegex = try? NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)", options: []),
                   let match = headerRegex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
                   let hashRange = Range(match.range(at: 1), in: trimmed),
                   let textRange = Range(match.range(at: 2), in: trimmed) {
                    let level = trimmed[hashRange].count
                    let headerText = String(trimmed[textRange])
                    segments.append(.header(level: level, text: headerText))
                    continue
                }
            }

            // Check for list items (- Item or * Item)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let itemText = String(trimmed.dropFirst(2))
                segments.append(.listItem(text: itemText))
                continue
            }

            // Regular paragraph with inline formatting
            if let attributed = parseInlineMarkdown(trimmed) {
                segments.append(.paragraph(attributed))
            }
        }

        return segments
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString? {
        var attributed = AttributedString(text)

        // Parse bold (double asterisk text double asterisk)
        do {
            let boldRegex = try NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
            let nsString = text as NSString
            let matches = boldRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let attrRange = attributed.range(of: String(text[range]))
                    if let attrRange = attrRange {
                        attributed[attrRange].font = .system(size: 14, weight: .bold, design: .rounded)
                    }
                }
            }
        } catch {
            print("Bold regex error: \(error)")
        }

        // Parse italic (single asterisk text single asterisk, not double)
        do {
            let italicRegex = try NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", options: [])
            let nsString = text as NSString
            let matches = italicRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let attrRange = attributed.range(of: String(text[range]))
                    if let attrRange = attrRange, var font = attributed[attrRange].font {
                        font = font.italic()
                        attributed[attrRange].font = font
                    }
                }
            }
        } catch {
            print("Italic regex error: \(error)")
        }

        // Parse links ([text](url))
        do {
            let linkRegex = try NSRegularExpression(pattern: "\\[(.+?)\\]\\((.+?)\\)", options: [])
            let nsString = text as NSString
            let matches = linkRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if match.numberOfRanges >= 3,
                   let textRange = Range(match.range(at: 1), in: text),
                   let urlRange = Range(match.range(at: 2), in: text),
                   let fullRange = Range(match.range, in: text) {

                    let linkText = String(text[textRange])
                    let urlString = String(text[urlRange])

                    if let attrRange = attributed.range(of: String(text[fullRange])),
                       let url = URL(string: urlString) {
                        attributed.replaceSubrange(attrRange, with: AttributedString(linkText))
                        let newRange = attrRange.lowerBound..<attributed.index(attrRange.lowerBound, offsetByCharacters: linkText.count)
                        attributed[newRange].link = url
                        attributed[newRange].foregroundColor = Color(hex: accentColor)
                        attributed[newRange].underlineStyle = .single
                    }
                }
            }
        } catch {
            print("Link regex error: \(error)")
        }

        return attributed
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
