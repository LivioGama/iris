import SwiftUI
import IRISCore
import IRISNetwork

/// Modern IRIS overlay with mode-specific visual layouts
struct GeminiResponseOverlayModern: View {
    @ObservedObject var geminiService: GeminiAssistantOrchestrator
    @StateObject private var modeCoordinator = ModeTransitionCoordinator()
    @Namespace private var animation

    @State private var localKeyMonitor: Any?
    @State private var globalKeyMonitor: Any?
    @State private var selectedOption: Int? = nil

    var currentConfig: ModeVisualConfig {
        return ModeConfigurationFactory.config(for: geminiService.currentIntent.rawValue)
    }

    var body: some View {
        content
            .onAppear {
                setupKeyMonitors()
            }
            .onDisappear {
                cleanupKeyMonitors()
            }
            .onChange(of: geminiService.currentIntent) {
                modeCoordinator.transitionTo(mode: geminiService.currentIntent.rawValue)
            }
    }

    // MARK: - Main Content

    private var content: some View {
        GeometryReader { geometry in
            ZStack {
                // Fully transparent background - always click-through to windows behind
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                VStack {
                    if isOverlayActive {
                        modeBasedContent
                            .allowsHitTesting(true)
                            .padding(.top, 40)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var isOverlayActive: Bool {
        geminiService.isListening || geminiService.isProcessing ||
        !geminiService.chatMessages.isEmpty || geminiService.capturedScreenshot != nil
    }

    // MARK: - Mode-Based Content

    @ViewBuilder
    private var modeBasedContent: some View {
        let constraints = currentConfig.sizeConstraints

        VStack(spacing: 0) {
            // Status bar (always visible)
            statusBar
                .padding(.horizontal, IRISSpacing.lg)
                .padding(.bottom, IRISSpacing.md)

            // Chat-style conversation view
            if !geminiService.chatMessages.isEmpty {
                chatView
                    .matchedGeometryEffect(id: "contentArea", in: animation)
            } else {
                // Loading/listening state (initial - no messages yet)
                loadingStateView
                    .matchedGeometryEffect(id: "contentArea", in: animation)
            }
        }
        .padding(IRISSpacing.lg)
        .frame(
            minWidth: constraints.minWidth,
            maxWidth: constraints.maxWidth,
            minHeight: constraints.minHeight,
            maxHeight: constraints.maxHeight
        )
        .glassmorphic(config: currentConfig, intensity: 0.4)
        .floatingShadow(config: currentConfig, radius: 45)
        .glowingBorder(config: currentConfig, lineWidth: 1.5)
        .clipShape(currentConfig.shapeForMode())
        .overlay(closeButton, alignment: .topTrailing)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .transition(IRISTransitions.morph)
        .animation(currentConfig.animationTiming, value: geminiService.currentIntent)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: IRISSpacing.sm) {
            Circle()
                .fill(geminiService.isListening ? Color.red : Color.green)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(geminiService.isListening ? Color.red : Color.green, lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0.5)
                )

            if geminiService.isListening {
                Text("Listening...")
                    .irisStyle(.body)
                    .foregroundColor(IRISColors.textPrimary)
            } else if geminiService.isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)

                Text("Processing...")
                    .irisStyle(.body)
                    .foregroundColor(IRISColors.textPrimary)
            } else {
                Text("Ready")
                    .irisStyle(.body)
                    .foregroundColor(IRISColors.textPrimary)
            }

            if let remaining = geminiService.remainingTimeout {
                Text("\(Int(ceil(remaining)))s")
                    .irisStyle(.caption)
                    .foregroundColor(IRISColors.textSecondary)
                    .monospacedDigit()
            }

            Spacer()
        }
    }

    // MARK: - Mode-Specific Views

    @ViewBuilder
    private func modeSpecificView(for parsedResponse: ICOIParsedResponse) -> some View {
        switch geminiService.currentIntent {
        case .codeImprovement:
            CodeImprovementModeView(
                parsedResponse: parsedResponse,
                config: currentConfig,
                selectedOption: $selectedOption
            )

        case .messageReply:
            MessageReplyModeView(
                parsedResponse: parsedResponse,
                config: currentConfig,
                screenshot: geminiService.capturedScreenshot,
                selectedOption: $selectedOption
            )

        case .summarize:
            SummarizeModeView(
                parsedResponse: parsedResponse,
                config: currentConfig,
                screenshot: geminiService.capturedScreenshot,
                selectedOption: $selectedOption
            )

        case .toneFeedback:
            ToneFeedbackModeView(
                parsedResponse: parsedResponse,
                config: currentConfig,
                screenshot: geminiService.capturedScreenshot,
                selectedOption: $selectedOption
            )

        case .chartAnalysis:
            ChartAnalysisModeView(
                parsedResponse: parsedResponse,
                config: currentConfig,
                screenshot: geminiService.capturedScreenshot,
                selectedOption: $selectedOption
            )

        case .general:
            GeneralModeView(
                parsedResponse: parsedResponse,
                config: currentConfig,
                screenshot: geminiService.capturedScreenshot,
                selectedOption: $selectedOption
            )
        }
    }

    // MARK: - Loading State

    private var loadingStateView: some View {
        VStack(spacing: IRISSpacing.lg) {
            // Show screenshot preview while listening/processing
            if let screenshot = geminiService.capturedScreenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: IRISRadius.normal))
                    .overlay(
                        RoundedRectangle(cornerRadius: IRISRadius.normal)
                            .stroke(IRISColors.stroke, lineWidth: 1)
                    )
                    .opacity(0.6)
            }

            if geminiService.isListening {
                if !geminiService.liveTranscription.isEmpty {
                    Text(geminiService.liveTranscription)
                        .irisStyle(.body)
                        .foregroundColor(IRISColors.textPrimary)
                        .padding(IRISSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: IRISRadius.normal)
                                .fill(Color.black.opacity(0.3))
                        )
                }
            } else if geminiService.isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                if !geminiService.liveGeminiResponse.isEmpty {
                    Text(geminiService.liveGeminiResponse)
                        .irisStyle(.body)
                        .foregroundColor(IRISColors.textPrimary)
                        .padding(IRISSpacing.md)
                        .frame(maxWidth: 600)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 400)
    }

    // MARK: - Chat View

    private var chatView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IRISSpacing.md) {
                // Show screenshot at top
                if let screenshot = geminiService.capturedScreenshot {
                    Image(nsImage: screenshot)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: IRISRadius.normal))
                        .overlay(
                            RoundedRectangle(cornerRadius: IRISRadius.normal)
                                .stroke(IRISColors.stroke, lineWidth: 1)
                        )
                        .opacity(0.6)
                }

                // Chat messages
                ForEach(Array(geminiService.chatMessages.enumerated()), id: \.offset) { index, message in
                    chatMessageView(message: message)
                }

                // Show live transcription while listening
                if geminiService.isListening && !geminiService.liveTranscription.isEmpty {
                    chatMessageView(message: ChatMessage(role: .user, content: geminiService.liveTranscription, timestamp: Date()))
                        .opacity(0.7)
                }

                // Show streaming Gemini response while processing
                if geminiService.isProcessing {
                    if !geminiService.liveGeminiResponse.isEmpty {
                        // Stream the response in real-time
                        chatMessageView(message: ChatMessage(role: .assistant, content: geminiService.liveGeminiResponse, timestamp: Date()))
                            .opacity(0.9)
                    } else {
                        // Just started processing
                        HStack(spacing: IRISSpacing.sm) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: currentConfig.accentColor))
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .irisStyle(.caption)
                                .foregroundColor(IRISColors.textSecondary)
                        }
                        .padding(IRISSpacing.md)
                    }
                }
            }
            .padding(IRISSpacing.lg)
        }
        .frame(maxWidth: 680, maxHeight: 500)
    }

    private func chatMessageView(message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: IRISSpacing.sm) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .foregroundColor(currentConfig.accentColor)
                    .font(.system(size: 12))
                    .padding(.top, 4)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: IRISSpacing.xs) {
                Text(message.content)
                    .irisStyle(.body)
                    .foregroundColor(IRISColors.textPrimary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(message.role == .user ? .trailing : .leading)
            }
            .padding(IRISSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: IRISRadius.normal)
                    .fill(message.role == .user ? Color.blue.opacity(0.2) : Color.black.opacity(0.3))
            )
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: closeResponse) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(IRISColors.textSecondary)
                .font(.system(size: 22))
                .padding(IRISSpacing.md)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Actions

    private func closeResponse() {
        geminiService.stopListening()
        geminiService.resetConversationState()
    }

    // MARK: - Key Monitors

    private func setupKeyMonitors() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 && !geminiService.chatMessages.isEmpty {
                DispatchQueue.main.async { closeResponse() }
                return nil
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 && !geminiService.chatMessages.isEmpty {
                DispatchQueue.main.async { closeResponse() }
            }
        }
    }

    private func cleanupKeyMonitors() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
