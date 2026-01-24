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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fully transparent background - always click-through
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                // Show ethereal elements when overlay is active
                if isOverlayActive {
                    etherealContent(geometry: geometry)
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
                        }
                        .onDisappear {
                            screenshotOffset = 0
                            showGradient = false
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // CRITICAL: Same condition as working overlay
    private var isOverlayActive: Bool {
        geminiService.isListening || geminiService.isProcessing ||
        !geminiService.chatMessages.isEmpty || geminiService.capturedScreenshot != nil
    }

    // MARK: - Ethereal Content

    @ViewBuilder
    private func etherealContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // Background: Gemini star (positioned relative to screenshot)
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 70)  // Higher up (was 100)

                if showGradient {
                    bigGeminiStar
                        .scaleEffect(1.54)
                        .opacity(0.35)
                        .transition(.opacity)
                }

                Spacer()
            }
            .allowsHitTesting(false)
            .zIndex(0)

            // Foreground: Screenshot and conversation
            VStack(spacing: 0) {
                // Top padding
                Spacer()
                    .frame(height: 60)

                // Screenshot with close button
                if let screenshot = geminiService.capturedScreenshot {
                    screenshotView(screenshot)
                        .offset(y: screenshotOffset)
                        .allowsHitTesting(true)
                }

                // Small spacing between screenshot and conversation
                Spacer()
                    .frame(height: 40)

                // Conversation section ON TOP of the star - no horizontal constraints for overflow
                ScrollView {
                    VStack(spacing: 20) {
                        // Show ALL finalized messages from chatMessages
                        ForEach(Array(geminiService.chatMessages.enumerated()), id: \.element.id) { index, message in
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

                                if let dynamicSchema = geminiService.dynamicUISchema, geminiService.useDynamicUI {
                                    // Show dynamic UI generated by AI
                                    DynamicUIRenderer(
                                        schema: dynamicSchema,
                                        screenshot: geminiService.capturedScreenshot,
                                        onAction: { action in
                                            handleDynamicUIAction(action)
                                        }
                                    )
                                    .frame(maxWidth: 900)
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

                        // Live transcription ONLY if actively speaking (not yet in chatMessages)
                        if !geminiService.liveTranscription.isEmpty {
                            userInputBubble(text: geminiService.liveTranscription, isLive: true)
                        }

                        // Live streaming response ONLY if actively streaming (not yet finalized in chatMessages)
                        if !geminiService.liveGeminiResponse.isEmpty {
                            geminiResponseBubble(text: geminiService.liveGeminiResponse, isStreaming: true)
                        }

                        // Listening hint (only when no messages yet)
                        if geminiService.capturedScreenshot != nil &&
                           geminiService.liveTranscription.isEmpty &&
                           !geminiService.isProcessing &&
                           geminiService.chatMessages.isEmpty {
                            Text("speak now")
                                .font(.system(size: 12, weight: .ultraLight, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(4)
                        }
                    }
                    .padding(.horizontal, 60)  // More side padding to allow text overflow
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
        // Authentic Gemini 4-pointed sparkle using proper curved shape
        ZStack {
            // Outer glow layer - very large and soft
            GeminiStarShape(sharpness: 0.68)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "4796E3").opacity(0.15),  // Gemini blue
                            Color(hex: "9177C7").opacity(0.12),  // Gemini purple
                            Color(hex: "CA6673").opacity(0.06),  // Gemini pink
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 800, height: 800)  // Huge outer glow
                .blur(radius: 60)
                .scaleEffect(geminiService.isProcessing ? 1.3 : 1.1)
                .opacity(geminiService.isProcessing ? 0.7 : 0.4)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: geminiService.isProcessing)

            // Mid layer - defines the shape more
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
                .scaleEffect(geminiService.isProcessing ? 1.25 : 1.08)
                .animation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true), value: geminiService.isProcessing)

            // Sharp inner layer - crisp definition
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
                .scaleEffect(geminiService.isProcessing ? 1.2 : 1.05)
                .animation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: geminiService.isProcessing)

            // Ultra-sharp core - maximum definition
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
                .scaleEffect(geminiService.isProcessing ? 1.15 : 1.02)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: geminiService.isProcessing)

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
                .scaleEffect(geminiService.isProcessing ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: geminiService.isProcessing)
        }
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
        Text(text)
            .font(.system(size: 20, weight: .light, design: .rounded))  // Bolder (was ultraLight)
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Color(hex: "9177C7").opacity(0.9)],  // Gemini purple
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .tracking(0.8)
            .lineSpacing(10)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 600)  // Max width to fit within star
            .shadow(color: .black.opacity(0.7), radius: 5, x: 0, y: 2)  // Bigger shadow
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 3)
            .shadow(color: Color(hex: "9177C7").opacity(0.4), radius: 25)
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
        ZStack(alignment: .topTrailing) {
            Image(nsImage: screenshot)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 400, maxHeight: 200)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            // Close button - top right, clickable
            Button(action: {
                geminiService.resetConversationState()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 32, height: 32)

                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .offset(x: 8, y: -8)
            .allowsHitTesting(true)  // Make button clickable
        }
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
        .frame(width: 600, height: 200)
        .clipped(antialiased: true)  // Prevent clipping of blur
        .drawingGroup()  // Better performance for complex animations
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

            // Audio visualization when listening
            if geminiService.isListening {
                audioWaves
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
