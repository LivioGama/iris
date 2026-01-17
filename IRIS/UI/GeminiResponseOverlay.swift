import SwiftUI
import IRISCore
import IRISNetwork

struct GeminiResponseOverlay: View {
    @ObservedObject var geminiService: GeminiAssistantOrchestrator

    @State private var localKeyMonitor: Any?
    @State private var globalKeyMonitor: Any?

    var body: some View {
        content
            .onAppear {
                // Local monitor (for when window has focus)
                localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 53 && !self.geminiService.chatMessages.isEmpty { // Escape key
                        DispatchQueue.main.async {
                            self.closeResponse()
                        }
                        return nil // Consume the event
                    }
                    return event
                }

                // Global monitor (for when window doesn't have focus)
                globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 53 && !self.geminiService.chatMessages.isEmpty { // Escape key
                        DispatchQueue.main.async {
                            self.closeResponse()
                        }
                    }
                }
            }
            .onDisappear {
                if let monitor = localKeyMonitor {
                    NSEvent.removeMonitor(monitor)
                }
                if let monitor = globalKeyMonitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
    }

    private var content: some View {
        ZStack {
            // Transparent background - click through when no overlay
            if geminiService.isListening || geminiService.isProcessing || !geminiService.chatMessages.isEmpty || geminiService.capturedScreenshot != nil {
                // Dark background when overlay is active - blocks clicks behind overlay
                Color.black.opacity(0.001)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(true)
                    .onTapGesture {
                        // Clicking background does nothing - prevents clicks from going through
                    }
            } else {
                // No overlay - completely transparent and click-through
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            VStack {
                Spacer()

                if geminiService.isListening || geminiService.isProcessing || !geminiService.chatMessages.isEmpty || geminiService.capturedScreenshot != nil {
                    mainContentView
                        .allowsHitTesting(true)
                        .onAppear {
                            print("👁️ Overlay appeared - isListening: \(geminiService.isListening), isProcessing: \(geminiService.isProcessing), messages: \(geminiService.chatMessages.count)")
                        }
                        .onDisappear {
                            print("👁️ Overlay disappeared - isListening: \(geminiService.isListening), isProcessing: \(geminiService.isProcessing), messages: \(geminiService.chatMessages.count)")
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContentView: some View {
        // Single unified overlay container
        HStack(alignment: .top, spacing: 20) {
            // Left side: Screenshot preview
            if let screenshot = geminiService.capturedScreenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 500, maxHeight: 600)
                    .clipped()
            }

            // Right side: Listening status and chat
            VStack(alignment: .leading, spacing: 12) {
                // Always show listening status in overlay
                HStack(spacing: 12) {
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
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    } else if geminiService.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)

                        Text("Processing...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    } else {
                        Text("Ready...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }

                    // Show countdown if timeout is active
                    if let remaining = geminiService.remainingTimeout {
                        Text("\(Int(ceil(remaining)))s")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .monospacedDigit()
                    }
                }

                // Chat messages
                if !geminiService.chatMessages.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(geminiService.chatMessages) { message in
                                    ChatMessageView(message: message)
                                        .environmentObject(geminiService)
                                        .id(message.id)
                                }
                            }
                        }
                        .frame(maxHeight: 600)
                        .onChange(of: geminiService.chatMessages.count) { _ in
                            // Scroll to the last message when new messages are added
                            if let lastMessage = geminiService.chatMessages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: geminiService.chatMessages.last?.content) { _ in
                            // Scroll when message content changes (e.g., loading bubble replaced with actual text)
                            if let lastMessage = geminiService.chatMessages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 700)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .shadow(color: Color.black.opacity(0.4), radius: 30)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.trailing, 24)
        .padding(.bottom, 24)
        .overlay(
            // Close button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        closeResponse()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 22))
                            .padding(12)
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
                Spacer()
            }
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }

    private var listeningView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .scaleEffect(1.5)
                                .opacity(0.5)
                        )

                    Text("Listening...")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }

                // Show countdown if timeout is active
                if let remaining = geminiService.remainingTimeout {
                    Text("\(Int(ceil(remaining)))s")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: Color.black.opacity(0.3), radius: 20)
            )

            if !geminiService.transcribedText.isEmpty {
                Text(geminiService.transcribedText)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.75))
                    )
                    .frame(maxWidth: 600)
            }
        }
        .padding(.bottom, 100)
    }

    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)

            Text("Analyzing with Gemini...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: Color.black.opacity(0.3), radius: 20)
        )
        .padding(.bottom, 100)
    }

    private var chatView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Conversation with Gemini")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Button(action: {
                    closeResponse()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 20))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .onHover { hovering in
                    // Visual feedback
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(geminiService.chatMessages) { message in
                            ChatMessageView(message: message)
                                .environmentObject(geminiService)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 500)
                .onChange(of: geminiService.chatMessages.count) { _ in
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = geminiService.chatMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: geminiService.chatMessages.last?.content) { _ in
                    // Scroll when message content changes (e.g., loading bubble replaced with actual text)
                    if let lastMessage = geminiService.chatMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .shadow(color: Color.black.opacity(0.4), radius: 30)
        )
        .frame(maxWidth: 800)
        .padding(.bottom, 100)
        .padding(.horizontal, 40)
        .allowsHitTesting(true) // Enable all interactions within chat view
    }

    private func closeResponse() {
        print("❌ Closing response overlay")

        // Clear chat first to prevent follow-up listener from starting
        geminiService.chatMessages.removeAll()

        // Stop listening to clear flags
        geminiService.stopListening()

        withAnimation {
            geminiService.geminiResponse = ""
            geminiService.transcribedText = ""
            geminiService.capturedScreenshot = nil
        }

        print("✅ Response overlay closed, ready for new blink")
    }
}

// Individual chat message view
struct ChatMessageView: View {
    let message: ChatMessage
    @EnvironmentObject var geminiService: GeminiAssistantOrchestrator

    private var messageItems: [(number: Int, text: String)] {
        parseNumberedList(from: message.content)
    }

    private var hasNumberedList: Bool {
        !messageItems.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Icon for user or assistant
            Image(systemName: message.role == .user ? "person.circle.fill" : "sparkles")
                .foregroundColor(message.role == .user ? .blue : .green)
                .font(.system(size: 16))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Gemini")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                // Show loading indicator for "..." content, or live streaming text
                if message.content == "..." {
                    // Check if we have live streaming response for this loading bubble
                    if message.role == .assistant && !geminiService.liveGeminiResponse.isEmpty {
                        Text(geminiService.liveGeminiResponse)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if message.role == .user && !geminiService.liveTranscription.isEmpty {
                        Text(geminiService.liveTranscription)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        LoadingDotsView()
                            .padding(.top, 4)
                    }
                } else if hasNumberedList && message.role == .assistant {
                    // Show header text if any (before the numbered list)
                    if let headerText = extractHeaderText(from: message.content) {
                        Text(headerText)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }

                    // Show clickable buttons for each numbered item
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(messageItems, id: \.number) { item in
                            Button(action: {
                                selectMessageNumber(item.number)
                            }) {
                                HStack {
                                    Text("\(item.number).")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 30, alignment: .leading)

                                    Text(item.text)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
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
                    }

                    // Show footer text if any (after the numbered list)
                    if let footerText = extractFooterText(from: message.content) {
                        Text(footerText)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .italic()
                            .padding(.top, 8)
                    }
                } else {
                    // Regular text message
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(message.role == .user ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
        )
    }

    private func selectMessageNumber(_ number: Int) {
        // Simulate voice input of the number
        Task {
            // Send the number to the service (it will add the user message internally)
            await geminiService.sendTextOnlyToGemini(prompt: "\(number)")
        }
    }

    private func parseNumberedList(from text: String) -> [(number: Int, text: String)] {
        var items: [(number: Int, text: String)] = []

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match patterns like "1. text" or "1) text"
            let pattern = #"^(\d+)[.\)]\s*(.+)$"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                if let numberRange = Range(match.range(at: 1), in: trimmed),
                   let textRange = Range(match.range(at: 2), in: trimmed),
                   let number = Int(trimmed[numberRange]) {
                    items.append((number: number, text: String(trimmed[textRange])))
                }
            }
        }

        return items
    }

    private func extractHeaderText(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        var headerLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Stop when we hit the first numbered item
            let pattern = #"^\d+[.\)]"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                break
            }
            if !trimmed.isEmpty {
                headerLines.append(trimmed)
            }
        }

        let header = headerLines.joined(separator: "\n")
        return header.isEmpty ? nil : header
    }

    private func extractFooterText(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        var footerLines: [String] = []
        var foundList = false
        var pastList = false

        let pattern = #"^\d+[.\)]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                foundList = true
                pastList = false
            } else if foundList && !trimmed.isEmpty {
                pastList = true
                footerLines.append(trimmed)
            } else if pastList && !trimmed.isEmpty {
                footerLines.append(trimmed)
            }
        }

        let footer = footerLines.joined(separator: " ")
        return footer.isEmpty ? nil : footer
    }
}

// Loading dots animation view
struct LoadingDotsView: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = 1
        }
    }
}
