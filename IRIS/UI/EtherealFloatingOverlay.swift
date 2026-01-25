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
        guard let screen = NSScreen.main else { return nil }

        // Use CGWindowListCreateImage to capture the screen
        let screenRect = screen.frame
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
                // Fully transparent background - always click-through
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                // Show ethereal elements when overlay is active OR during dismiss animation
                if isOverlayActive || isDismissing {
                    etherealContent(geometry: geometry)
                        .offset(y: dismissAnimationOffset)
                        .opacity(isDismissing ? max(0.0, 1.0 - Double(abs(dismissAnimationOffset)) / 300.0) : 1.0)
                        .animation(.easeOut(duration: 0.3), value: dismissAnimationOffset)
                        .onAppear {
                            // Animate screenshot sliding up (less offset to stay in view)
                            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                screenshotOffset = -50
                            }
                            // Show gradient after screenshot starts moving
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeIn(duration: 0.6)) {
                                    showGradient = true
                                }
                            }
                            // Start scroll monitor
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

        // Add global monitor for keyboard events (Escape key to dismiss)
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [self] event in
            handleKeyboardEvent(event)
        }

        print("🖱️ Scroll monitor started for dismiss gesture")
        print("⌨️ Keyboard monitor started for Escape key dismiss")
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
        (geminiService.demoAllTemplates && geminiService.dynamicUISchema != nil) ||
        geminiService.isAnalyzingScreenshot || !geminiService.proactiveSuggestions.isEmpty
    }

    // MARK: - Ethereal Content

    @ViewBuilder
    private func etherealContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // Background: Gemini star (positioned relative to screenshot)
            // Use GeometryReader to position without clipping
            GeometryReader { geo in
                if showGradient {
                    bigGeminiStar
                        .scaleEffect(0.75)
                        .opacity(0.35)
                        .transition(.opacity)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.4)  // Centered, slightly above middle
                }
            }
            .allowsHitTesting(false)
            .zIndex(0)

            // Foreground: Screenshot and conversation
            VStack(spacing: 0) {
                // Top padding
                Spacer()
                    .frame(height: 24)

                // Screenshot with close button
                // Only the close button should be interactive, not the whole screenshot
                if let screenshot = geminiService.capturedScreenshot {
                    screenshotView(screenshot)
                        .offset(y: screenshotOffset)
                }

                // Small spacing between screenshot and conversation
                Spacer()
                    .frame(height: 12)

                // Conversation section ON TOP of the star - shows last 2 messages, scrollable for history
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // PROACTIVE MODE: Show analyzing indicator or suggestions
                            if geminiService.isAnalyzingScreenshot {
                                analyzingIndicator
                            } else if !geminiService.proactiveSuggestions.isEmpty {
                                ProactiveSuggestionsView(
                                    suggestions: geminiService.proactiveSuggestions,
                                    context: geminiService.detectedContext,
                                    onSelect: { suggestion in
                                        Task {
                                            await geminiService.executeProactiveSuggestion(suggestion)
                                        }
                                    },
                                    onCustomRequest: {
                                        // User wants to speak custom request - suggestions will be cleared when they speak
                                        print("🎤 Custom request requested - listening active")
                                    }
                                )
                                .frame(maxWidth: 500)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            // Show messages with fade effect for older ones
                            // Last 2 messages are fully visible, older ones fade out
                            ForEach(Array(geminiService.chatMessages.enumerated()), id: \.element.id) { index, message in
                                let messageCount = geminiService.chatMessages.count
                                let isRecentMessage = index >= messageCount - 2
                                let fadeOpacity = isRecentMessage ? 1.0 : max(0.3, 1.0 - Double(messageCount - index - 2) * 0.25)

                                Group {
                                    if message.role == .user {
                                        userInputBubble(text: message.content, isLive: false)
                                    } else {
                                        // Divider BEFORE Gemini response
                                        Spacer()
                                            .frame(height: 30)

                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: "4796E3").opacity(0.5),
                                                        Color(hex: "9177C7").opacity(0.5)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: 400, height: 1)
                                            .shadow(color: Color(hex: "4796E3").opacity(0.6), radius: 4)

                                        Spacer()
                                            .frame(height: 30)

                                        // Check if we have a dynamic UI schema with actual components to render
                                        let hasSchema = geminiService.dynamicUISchema != nil
                                        let componentCount = geminiService.dynamicUISchema?.components.count ?? 0
                                        let _ = try? "🎨 UI Check - hasSchema: \(hasSchema), components: \(componentCount), useDynamicUI: \(geminiService.useDynamicUI)\n".appendLine(to: "/tmp/iris_ui.log")

                                        if let schema = geminiService.dynamicUISchema,
                                           !schema.components.isEmpty,
                                           geminiService.useDynamicUI {
                                            // Render the AI-generated UI layout
                                            let _ = try? "🎨 Rendering DynamicUIRenderer with \(schema.components.count) components\n".appendLine(to: "/tmp/iris_ui.log")
                                            DynamicUIRenderer(
                                                schema: schema,
                                                screenshot: geminiService.capturedScreenshot,
                                                onAction: { action in
                                                    handleDynamicUIAction(action)
                                                }
                                            )
                                            .frame(maxWidth: schema.layout.maxWidth ?? 900)
                                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                        } else if isCodeImprovementResponse(at: index),
                                           let parsedResponse = geminiService.parsedICOIResponse {
                                            codeImprovementBubble(parsedResponse)
                                        } else {
                                            geminiResponseBubble(text: message.content, isStreaming: false)
                                        }

                                        // Divider AFTER Gemini response
                                        Spacer()
                                            .frame(height: 30)

                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: "9177C7").opacity(0.5),
                                                        Color(hex: "4796E3").opacity(0.5)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: 400, height: 1)
                                            .shadow(color: Color(hex: "9177C7").opacity(0.6), radius: 4)

                                        Spacer()
                                            .frame(height: 30)
                                    }
                                }
                                .opacity(fadeOpacity)
                                .id(message.id)
                            }

                            // Live transcription ONLY if actively speaking (not yet in chatMessages)
                            if !geminiService.liveTranscription.isEmpty {
                                userInputBubble(text: geminiService.liveTranscription, isLive: true)
                                    .id("liveTranscription")
                            }

                            // Live streaming response ONLY if actively streaming (not yet finalized in chatMessages)
                            if !geminiService.liveGeminiResponse.isEmpty {
                                geminiResponseBubble(text: geminiService.liveGeminiResponse, isStreaming: true)
                                    .id("liveResponse")
                            }

                            // Listening hint (only when no messages yet and not in proactive mode)
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

                            // Bottom anchor for auto-scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottomAnchor")
                        }
                        .padding(.horizontal, 60)  // More side padding to allow text overflow
                    }
                    .onChange(of: geminiService.chatMessages.count) { _ in
                        // Auto-scroll to bottom when new messages arrive
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: geminiService.liveGeminiResponse) { _ in
                        // Auto-scroll during streaming response
                        if !geminiService.liveGeminiResponse.isEmpty {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo("liveResponse", anchor: .bottom)
                            }
                        }
                    }
                }
                .allowsHitTesting(false)

                Spacer()
            }
            .zIndex(100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            Color(hex: "4796E3").opacity(0.15),
                            Color(hex: "9177C7").opacity(0.12),
                            Color(hex: "CA6673").opacity(0.06),
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
                            Color(hex: "4796E3").opacity(0.25),
                            Color(hex: "9177C7").opacity(0.2),
                            Color(hex: "CA6673").opacity(0.1),
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
                            Color(hex: "4796E3").opacity(0.35),
                            Color(hex: "9177C7").opacity(0.28),
                            Color(hex: "CA6673").opacity(0.15),
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
                            Color(hex: "4796E3").opacity(0.45),
                            Color(hex: "9177C7").opacity(0.35),
                            Color(hex: "CA6673").opacity(0.2),
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
                            Color(hex: "4796E3").opacity(0.5),
                            Color(hex: "9177C7").opacity(0.4),
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
                            Color(hex: "4796E3").opacity(0.6),
                            Color(hex: "9177C7").opacity(0.3),
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
                                Color(hex: "4796E3").opacity(0.5),
                                Color(hex: "9177C7").opacity(0.45),
                                Color(hex: "CA6673").opacity(0.4)
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
                                colors: [Color(hex: "4796E3"), Color(hex: "9177C7")],
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
    private func userInputBubble(text: String, isLive: Bool) -> some View {
        Text(text)
            .font(.system(size: isLive ? 28 : 24, weight: .light, design: .rounded))  // Bolder (was ultraLight)
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Color(hex: "4796E3").opacity(0.9)],  // Gemini blue
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .tracking(1)
            .lineSpacing(8)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 600)  // Max width to fit within star
            .shadow(color: .black.opacity(0.7), radius: 5, x: 0, y: 2)  // Bigger shadow
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 3)
            .shadow(color: Color(hex: "4796E3").opacity(0.4), radius: 25)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    @ViewBuilder
    private func geminiResponseBubble(text: String, isStreaming: Bool) -> some View {
        // Use schema's accent color if available, otherwise default Gemini purple
        let accentColor = geminiService.dynamicUISchema?.theme.accentColor ?? "9177C7"
        let secondaryColor = geminiService.dynamicUISchema?.theme.secondaryColor ?? accentColor

        // Parse text for code blocks and render appropriately
        MarkdownResponseView(
            text: text,
            accentColor: accentColor,
            secondaryColor: secondaryColor
        )
        .frame(maxWidth: 700)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                                    Color(hex: "4796E3").opacity(0.3),  // Gemini blue
                                    Color(hex: "9177C7").opacity(0.2),  // Gemini purple
                                    Color(hex: "CA6673").opacity(0.08),  // Gemini red/pink
                                    Color.clear
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
                                    Color(hex: "9177C7").opacity(0.25),  // Gemini purple
                                    Color(hex: "4796E3").opacity(0.12),  // Gemini blue
                                    Color.clear
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
                                Color(hex: "4796E3").opacity(0.2),
                                Color(hex: "9177C7").opacity(0.1),
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
                            colors: [.white, Color(hex: "4796E3").opacity(0.9)],  // Gemini blue
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(1)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)
                    .shadow(color: Color(hex: "4796E3").opacity(0.3), radius: 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
            } else if let lastUserMessage = geminiService.chatMessages.last(where: { $0.role == .user }) {
                // Show last user message (stays visible during processing and streaming)
                Text(lastUserMessage.content)
                    .font(.system(size: 24, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), Color(hex: "4796E3").opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(0.8)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)
                    .shadow(color: Color(hex: "4796E3").opacity(0.25), radius: 15)
                    .zIndex(100)
            } else if !geminiService.transcribedText.isEmpty {
                // Fallback: show transcribed text if available
                Text(geminiService.transcribedText)
                    .font(.system(size: 24, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), Color(hex: "4796E3").opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(0.8)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)
                    .shadow(color: Color(hex: "4796E3").opacity(0.25), radius: 15)
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
                                Color(hex: "4796E3").opacity(0.2),  // Gemini blue
                                Color(hex: "9177C7").opacity(0.15),  // Gemini purple
                                Color(hex: "CA6673").opacity(0.1),  // Gemini red/pink
                                Color.clear
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
                VStack(spacing: 16) {
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
                        VStack(spacing: 12) {
                            Text(geminiService.liveGeminiResponse)
                                .font(.system(size: 20, weight: .light, design: .rounded))
                                .foregroundColor(.white)  // Solid white for readability
                                .tracking(0.4)
                                .lineSpacing(8)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(hex: "9177C7").opacity(0.2))  // More visible background
                                        .blur(radius: 8)
                                )
                                .shadow(color: Color(hex: "9177C7").opacity(0.4), radius: 15)

                            // Streaming indicator
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(Color(hex: "9177C7").opacity(0.6))  // Gemini purple
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
                VStack(spacing: 16) {
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
                                        colors: [.white, Color(hex: "9177C7")],  // Gemini purple
                                        startPoint: .topLeading,
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
                                        .fill(Color(hex: "9177C7").opacity(0.1))  // Gemini purple
                                        .blur(radius: 8)
                                )
                                .shadow(color: Color(hex: "9177C7").opacity(0.25), radius: 15)

                            // Streaming indicator
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(Color(hex: "9177C7").opacity(0.6))  // Gemini purple
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
        // Center all messages
        VStack(spacing: 4) {
            Text(message.content)
                .font(.system(size: 20, weight: .light, design: .rounded))
                .foregroundColor(.white)  // Solid white for readability
                .tracking(0.4)
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            message.role == .user ?
                                Color(hex: "4796E3").opacity(0.2) :  // Gemini blue - more visible
                                Color(hex: "9177C7").opacity(0.2)    // Gemini purple - more visible
                        )
                        .blur(radius: 8)
                )
                .shadow(
                    color: (message.role == .user ? Color(hex: "4796E3") : Color(hex: "9177C7")).opacity(0.4),
                    radius: 15
                )
        }
        .frame(maxWidth: 700)
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
                }
            }
        }
    }

    // MARK: - Text View

    @ViewBuilder
    private func textView(_ content: String) -> some View {
        Text(content)
            .font(.system(size: 18, weight: .light, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Color(hex: accentColor).opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .tracking(0.5)
            .lineSpacing(8)
            .multilineTextAlignment(.leading)
            .shadow(color: .black.opacity(0.7), radius: 5, x: 0, y: 2)
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 3)
            .shadow(color: Color(hex: secondaryColor).opacity(0.3), radius: 20)
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
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(maxHeight: 300)
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
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(Color(hex: accentColor))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: accentColor).opacity(0.15))
            )
    }

    // MARK: - Parsing

    private enum MarkdownSegment {
        case text(String)
        case codeBlock(code: String, language: String?)
        case inlineCode(String)
    }

    private func parseMarkdown() -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        var remaining = text

        // Pattern for fenced code blocks: ```language\ncode\n```
        let codeBlockPattern = "```(\\w*)\\n([\\s\\S]*?)```"

        while !remaining.isEmpty {
            if let regex = try? NSRegularExpression(pattern: codeBlockPattern),
               let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {

                // Get text before the code block
                if let beforeRange = Range(NSRange(location: 0, length: match.range.location), in: remaining) {
                    let beforeText = String(remaining[beforeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !beforeText.isEmpty {
                        segments.append(.text(beforeText))
                    }
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
                // No more code blocks, add remaining text
                let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    segments.append(.text(trimmed))
                }
                break
            }
        }

        // If no segments were found, return the whole text
        if segments.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(.text(text))
        }

        return segments
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
