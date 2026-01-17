import Foundation
import AppKit
import AVFoundation
import IRISCore
import IRISNetwork
import IRISMedia
import IRISVision
import GoogleGenerativeAI

/// High-level orchestrator for Gemini assistant interactions
/// Responsibility: Workflow coordination ONLY - delegates to specialized services
public class GeminiAssistantOrchestrator: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published public var isListening = false
    @Published public var transcribedText = ""
    @Published public var liveTranscription = "" // Real-time partial transcription
    @Published public var geminiResponse = "" // Kept for backward compatibility
    @Published public var liveGeminiResponse = "" // Real-time streaming Gemini response
    @Published public var chatMessages: [ChatMessage] = []
    @Published public var isProcessing = false
    @Published public var capturedScreenshot: NSImage?
    @Published public var remainingTimeout: TimeInterval? = nil

    // MARK: - Services
    private let geminiClient: GeminiClient
    private let conversationManager: ConversationManager
    internal let voiceInteractionService: VoiceInteractionService
    private let messageExtractionService: MessageExtractionService
    private let screenshotService: ScreenshotService
    private let sentimentAnalysisService = SentimentAnalysisService.shared
    private let visionTextDetector = VisionTextDetector()

    // MARK: - State
    private var extractedMessages: [String] = []
    private var waitingForMessageSelection = false
    private var waitingForMessageExtraction = false
    private var currentFocusedElement: DetectedElement?

    // Deduplication
    private var lastSentPrompt: String = ""
    private var lastSentTime: Date?
    private let deduplicationWindow: TimeInterval = 5.0

    // Countdown timer
    private var countdownTimer: Timer?
    private var timeoutStartTime: Date?

    // Blink cooldown
    private var lastBlinkTime: Date?
    private let blinkCooldownPeriod: TimeInterval = 2.0  // 2 seconds cooldown

    // Prompts
    private let messageExtractionPrompt = "Looking at this chat screenshot, please list all the visible messages you can see in the conversation area (the blue message bubbles on the right side). Number each message (1., 2., 3., etc.). Ignore the contacts list on the left. ONLY list the messages, don't add any other text."

    // MARK: - Initialization
    public init(
        geminiClient: GeminiClient,
        conversationManager: ConversationManager,
        voiceInteractionService: VoiceInteractionService,
        messageExtractionService: MessageExtractionService,
        screenshotService: ScreenshotService
    ) {
        self.geminiClient = geminiClient
        self.conversationManager = conversationManager
        self.voiceInteractionService = voiceInteractionService
        self.messageExtractionService = messageExtractionService
        self.screenshotService = screenshotService

        print("🔑 GeminiAssistantOrchestrator initialized with shared client")
        super.init()
    }

    // MARK: - Public API
    public func prewarm() {
        voiceInteractionService.prewarm()
    }

    public func handleBlink(at point: CGPoint, focusedElement: DetectedElement?) {
        // Ignore blinks when overlay is already open (has chat messages or screenshot)
        guard chatMessages.isEmpty && capturedScreenshot == nil else {
            print("⚠️ Overlay already open, ignoring blink")
            return
        }

        // Prevent concurrent blink handling
        guard !isListening && !isProcessing else {
            print("⚠️ Already processing a blink, skipping")
            return
        }

        // Cooldown check - prevent rapid re-triggering
        if let lastBlink = lastBlinkTime, Date().timeIntervalSince(lastBlink) < blinkCooldownPeriod {
            print("⚠️ Blink cooldown active, skipping")
            return
        }

        lastBlinkTime = Date()
        print("🔵 Blink detected at \(point)")

        // Capture screenshot with error handling
        guard let screenshot = screenshotService.captureCurrentScreen() else {
            print("❌ Failed to capture screenshot")
            self.isProcessing = false
            self.isListening = false
            return
        }

        // Store screenshot and focused element
        self.capturedScreenshot = screenshot
        self.currentFocusedElement = focusedElement

        // Reset conversation for new interaction
        conversationManager.clearHistory()

        // Clear chat messages
        self.chatMessages.removeAll()

        // Start voice interaction with 5-second timeout
        let timeoutDuration: TimeInterval = 5.0

        // Update UI state on main thread BEFORE starting timer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.remainingTimeout = timeoutDuration
            self.timeoutStartTime = Date()
            print("⏱️ Starting countdown timer with timeout: \(timeoutDuration)s")
            self.startCountdownTimer(totalTimeout: timeoutDuration)
            print("⏱️ Timer started, continuing...")

            // CRITICAL: Set isListeningForBuffers BEFORE startListening so buffers are sent
            self.isListeningForBuffers = true
            self.bufferCount = 0
            print("🎤 Set isListeningForBuffers = true BEFORE startListening")
        }

        voiceInteractionService.startListening(timeout: timeoutDuration, useExternalAudio: true, onSpeechDetected: { [weak self] in
            print("🎤 Speech detected! Stopping countdown...")
            // Stop countdown when speech is detected
            DispatchQueue.main.async {
                // Now mark as listening since speech was actually detected
                self?.isListening = true
                self?.isListeningForBuffers = true
                self?.bufferCount = 0
                print("🎤 Set isListening and isListeningForBuffers = true after speech detected")

                self?.countdownTimer?.invalidate()
                self?.countdownTimer = nil
                self?.remainingTimeout = nil

                // Add placeholder user message bubble immediately
                self?.chatMessages.append(ChatMessage(role: .user, content: "...", timestamp: Date()))
            }
        }, onPartialResult: { [weak self] partialText in
            // Update live transcription in real-time
            DispatchQueue.main.async {
                self?.liveTranscription = partialText
            }
        }) { [weak self] prompt in
            print("📥📥📥 VOICE CALLBACK FIRED - Prompt: '\(prompt)' (length: \(prompt.count))")

            guard let self = self else {
                print("⚠️ Voice callback: self is nil")
                return
            }

            // Stop countdown timer when user finishes speaking
            print("⏱️ Stopping countdown timer")
            DispatchQueue.main.async {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.timeoutStartTime = nil
                self.remainingTimeout = nil
            }

            print("🔄 Setting isListening = false, isListeningForBuffers = false")
            DispatchQueue.main.async {
                self.isListening = false
                self.isListeningForBuffers = false
                self.transcribedText = prompt
                self.liveTranscription = "" // Clear live transcription

                // Replace the loading bubble with actual transcription
                if let lastIndex = self.chatMessages.lastIndex(where: { $0.role == .user && $0.content == "..." }) {
                    self.chatMessages[lastIndex] = ChatMessage(role: .user, content: prompt, timestamp: Date())
                }
            }

            // Check for "stop" command to exit analysis mode
            print("🔍 Checking if stop command...")
            if self.isStopCommand(prompt) {
                print("🛑🛑🛑 Stop command detected, returning to indicator mode")
                DispatchQueue.main.async {
                    self.capturedScreenshot = nil
                    self.isProcessing = false
                    self.isListening = false
                    self.chatMessages.removeAll()
                }
                return
            }

            // Only process if there's actual input
            print("🔍 Checking if prompt is empty...")
            guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("⚠️⚠️⚠️ No voice input detected (empty prompt) - CLOSING OVERLAY")
                DispatchQueue.main.async {
                    self.capturedScreenshot = nil
                    self.isProcessing = false
                    self.isListening = false
                    self.chatMessages.removeAll()
                }
                return
            }

            // Send to Gemini
            print("✅✅✅ Valid prompt received, sending to Gemini with screenshot")
            Task { @MainActor in
                await self.sendToGemini(screenshot: screenshot, prompt: prompt, focusedElement: focusedElement)
            }
        }
    }

    // Use an atomic or non-isolated flag for the audio thread to check without actor hop
    private var isListeningForBuffers = false

    private var bufferCount = 0
    public func receiveAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Optimized check: no actor hop for every buffer
        if isListeningForBuffers {
            bufferCount += 1
            if bufferCount % 100 == 0 {
                print("🎤 Received \(bufferCount) audio buffers")
            }
            voiceInteractionService.receiveBuffer(buffer)
        }
    }

    public func stopListening() {
        self.isListening = false
        self.isListeningForBuffers = false
        voiceInteractionService.stopListening()

        // Update blink time to prevent immediate re-opening
        self.lastBlinkTime = Date()
        print("🛑 Updated lastBlinkTime to prevent immediate re-opening")

        DispatchQueue.main.async {
            print("🛑 stopListening: Clearing listening state and UI")

            // Stop countdown timer directly (no nested async)
            self.countdownTimer?.invalidate()
            self.countdownTimer = nil
            self.timeoutStartTime = nil
            self.remainingTimeout = nil

            self.isListening = false
            self.transcribedText = ""
            self.capturedScreenshot = nil
            self.chatMessages.removeAll()

            // Only clear isProcessing if we're not actually processing a Gemini request
            if !self.isProcessing {
                self.geminiResponse = ""
            }
        }

        print("🛑 Listening stopped, ready for new blink")
    }

    // MARK: - Private Methods
    private func sendToGemini(screenshot: NSImage, prompt: String, focusedElement: DetectedElement?) async {
        print("📤 sendToGemini called with prompt: '\(prompt)'")

        // Check for duplicate prompts
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedPrompt == lastSentPrompt.lowercased(),
           let lastTime = lastSentTime,
           Date().timeIntervalSince(lastTime) < deduplicationWindow {
            print("⚠️ Duplicate prompt detected, skipping (last: '\(lastSentPrompt)', current: '\(normalizedPrompt)', time diff: \(Date().timeIntervalSince(lastTime))s)")
            await MainActor.run {
                self.isProcessing = false
            }
            return
        }

        print("✅ Not a duplicate - last: '\(lastSentPrompt)', current: '\(normalizedPrompt)'")
        lastSentPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSentTime = Date()

        print("✅ Setting isProcessing = true and adding messages")
        await MainActor.run {
            self.isProcessing = true
            // Don't add user message here - it's already been added and replaced from loading bubble

            // Add assistant loading bubble immediately
            self.chatMessages.append(ChatMessage(role: .assistant, content: "...", timestamp: Date()))
        }

        print("✅ isProcessing set, continuing...")

        // Handle message selection flow
        var actualPrompt = prompt

        if waitingForMessageSelection && sentimentAnalysisService.detectsMessageNumber(in: prompt) == nil {
            print("🔄 Resetting message selection state")
            waitingForMessageSelection = false
            extractedMessages.removeAll()
        }

        if waitingForMessageSelection, let messageNumber = sentimentAnalysisService.detectsMessageNumber(in: prompt) {
            await handleMessageSelection(messageNumber: messageNumber)
            return
        } else if sentimentAnalysisService.detectsSentimentRequest(in: prompt) {
            print("🎭 Sentiment analysis request detected")
            actualPrompt = messageExtractionPrompt
            waitingForMessageExtraction = true
        }

        // Convert screenshot to base64
        guard let base64Image = screenshotService.imageToBase64(screenshot) else {
            await MainActor.run {
                self.geminiResponse = "Error: Failed to convert screenshot"
                self.isProcessing = false
            }
            return
        }

        // Build prompt with context
        let fullPrompt = buildPrompt(actualPrompt: actualPrompt, focusedElement: focusedElement)

        // Convert base64 string to Data
        guard let imageData = Data(base64Encoded: base64Image) else {
            await MainActor.run {
                self.geminiResponse = "Error: Failed to decode image data"
                self.isProcessing = false
            }
            return
        }

        // Create message using Google SDK types
        let initialMessage = ModelContent(
            role: "user",
            parts: [
                ModelContent.Part.text(fullPrompt),
                ModelContent.Part.data(mimetype: "image/jpeg", imageData)
            ]
        )

        conversationManager.addMessage(initialMessage)

        // Send streaming request
        print("🌐 About to send Gemini API streaming request...")
        do {
            print("🌐 Calling geminiClient.sendStreamingRequest...")

            // Clear previous live response
            await MainActor.run {
                self.liveGeminiResponse = ""
            }

            let responseText = try await geminiClient.sendStreamingRequest(history: conversationManager.getHistory()) { [weak self] partialText in
                // Update live Gemini response in real-time
                Task { @MainActor in
                    self?.liveGeminiResponse = partialText
                }
            }

            print("🌐 Received complete response from Gemini!")
            print("✅ Got response text: \(responseText.prefix(100))...")

            // Clear live response now that we have the final version
            await MainActor.run {
                self.liveGeminiResponse = ""
            }

            // Add response to history
            let assistantMessage = ModelContent(
                role: "model",
                parts: [ModelContent.Part.text(responseText)]
            )
            conversationManager.addMessage(assistantMessage)

            // Handle message extraction flow
            if waitingForMessageExtraction {
                print("📤 Handling message extraction...")
                await handleMessageExtraction(responseText: responseText)
            } else {
                print("💬 Handling normal response...")
                await handleNormalResponse(responseText: responseText)
            }

        } catch {
            print("❌❌❌ Request failed with error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")

            // Provide helpful error message
            let errorMessage: String
            if let geminiError = error as? GeminiError, case .missingAPIKey = geminiError {
                errorMessage = "API Key not configured. Please set your Gemini API key in the menu bar settings."
            } else {
                errorMessage = "Error: \(error.localizedDescription)"
            }

            await MainActor.run {
                self.geminiResponse = errorMessage
                self.isProcessing = false
            }
        }
    }

    public func sendTextOnlyToGemini(prompt: String) async {
        // Check for duplicates
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedPrompt == lastSentPrompt.lowercased(),
           let lastTime = lastSentTime,
           Date().timeIntervalSince(lastTime) < deduplicationWindow {
            print("⚠️ Duplicate prompt detected, skipping")
            return
        }

        lastSentPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSentTime = Date()

        await MainActor.run {
            self.isProcessing = true
            // Don't add user message here - it's already been added and replaced from loading bubble in follow-up flow
            // Only add it if it's not already there (for direct calls)
            if !self.chatMessages.contains(where: { $0.role == .user && $0.content == prompt }) {
                self.chatMessages.append(ChatMessage(role: .user, content: prompt, timestamp: Date()))
            }

            // Add assistant loading bubble immediately
            self.chatMessages.append(ChatMessage(role: .assistant, content: "...", timestamp: Date()))
        }

        // Handle message selection
        var actualPrompt = prompt

        if waitingForMessageSelection && sentimentAnalysisService.detectsMessageNumber(in: prompt) == nil {
            waitingForMessageSelection = false
            extractedMessages.removeAll()
        }

        if waitingForMessageSelection, let messageNumber = sentimentAnalysisService.detectsMessageNumber(in: prompt) {
            await handleMessageSelection(messageNumber: messageNumber)
            return
        } else if sentimentAnalysisService.detectsSentimentRequest(in: prompt) {
            actualPrompt = messageExtractionPrompt
            waitingForMessageExtraction = true
        }

        // Add to conversation history
        let userMessage = ModelContent(
            role: "user",
            parts: [ModelContent.Part.text(actualPrompt)]
        )
        conversationManager.addMessage(userMessage)

        do {
            // Clear previous live response
            await MainActor.run {
                self.liveGeminiResponse = ""
            }

            let responseText = try await geminiClient.sendStreamingRequest(history: conversationManager.getHistory()) { [weak self] partialText in
                // Update live Gemini response in real-time
                Task { @MainActor in
                    self?.liveGeminiResponse = partialText
                }
            }

            // Clear live response now that we have the final version
            await MainActor.run {
                self.liveGeminiResponse = ""
            }

            let assistantMessage = ModelContent(
                role: "model",
                parts: [ModelContent.Part.text(responseText)]
            )
            conversationManager.addMessage(assistantMessage)

            if waitingForMessageExtraction {
                await handleMessageExtraction(responseText: responseText)
            } else {
                await handleNormalResponse(responseText: responseText)
            }

        } catch {
            // Provide helpful error message
            let errorMessage: String
            if let geminiError = error as? GeminiError, case .missingAPIKey = geminiError {
                errorMessage = "API Key not configured. Please set your Gemini API key in the menu bar settings."
            } else {
                errorMessage = "Error: \(error.localizedDescription)"
            }

            await MainActor.run {
                self.geminiResponse = errorMessage
                self.isProcessing = false
            }
        }
    }

    // MARK: - Helper Methods

    /// Detects stop commands using local keyword matching (no API call needed)
    private func isStopCommand(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // List of stop command keywords and phrases
        let stopKeywords = [
            "stop",
            "cancel",
            "exit",
            "quit",
            "close",
            "nevermind",
            "never mind",
            "forget it",
            "no thanks",
            "dismiss"
        ]

        // Check for exact matches or if the text starts with any of these keywords
        for keyword in stopKeywords {
            if normalized == keyword || normalized.hasPrefix(keyword + " ") {
                return true
            }
        }

        return false
    }

    private func buildPrompt(actualPrompt: String, focusedElement: DetectedElement?) -> String {
        var fullPrompt = "You are an AI assistant helping a user who is using eye-tracking and voice control."

        if let element = focusedElement {
            let centerX = element.bounds.midX
            let centerY = element.bounds.midY

            fullPrompt += """


            🎯 FOCUS AREA:
            The user is looking at: "\(element.label)" (type: \(element.type))
            Location on screen: approximately at (\(Int(centerX)), \(Int(centerY)))

            CRITICAL: Focus your analysis ONLY on this specific area in the screenshot. Ignore other parts of the screen.
            Look at the content around the coordinates (\(Int(centerX)), \(Int(centerY))) in the image.
            """
        }

        fullPrompt += """


        IMPORTANT CONTEXT UNDERSTANDING:
        - Focus on the area the user is looking at (specified above)
        - Answer ANY question ABOUT that area (sentiment, meaning, what to reply, summary, etc.)

        MESSAGING APP RULES (WhatsApp, Telegram, iMessage, etc.):
        - Messages on the RIGHT side = sent BY THE USER (they wrote these)
        - Messages on the LEFT side = received FROM OTHERS (someone else wrote these)
        - Green/blue bubbles on right = USER's messages
        - Gray/white bubbles on left = OTHER PERSON's messages
        - Right-aligned text = USER sent it
        - Left-aligned text = OTHER PERSON sent it
        - When user asks "what should I reply/answer/say", they want YOU to suggest what THEY should write back
        - Context: The user can see the conversation but wants help composing a response

        VALID QUESTION TYPES (ALL are acceptable and should be answered):
        - "What does this say?" / "What am I looking at?"
        - "What should I reply?" / "How should I respond?"
        - "What's the sentiment?" / "How does this feel?" / "What's the tone?"
        - "Summarize this" / "Explain this" / "What does this mean?"
        - ANY question about content, emotions, meaning, or suggestions related to the focused area

        OTHER IMPORTANT RULES:
        - The user is asking about what THEY should do/say/write, not explaining what others said
        - Use the content at the specified coordinates to answer their question
        - If looking at a message thread, identify who sent each message based on alignment

        User's voice request: "\(actualPrompt.isEmpty ? "What am I looking at?" : actualPrompt)"

        Response guidelines:
        - Be brief and actionable (2-3 sentences unless asked for more)
        - Use plain text only - NO markdown, NO asterisks, NO formatting symbols
        - Understand the user's intent from context (e.g., if they ask about replying, suggest what they should say)
        - Focus on being helpful for their next action
        - Answer questions ABOUT the focused area - ALL questions are valid
        - In chats: Always correctly identify message alignment (left=received, right=sent)
        """

        return fullPrompt
    }

    private func handleMessageSelection(messageNumber: Int) async {
        print("🔢 Message number selected: \(messageNumber)")

        guard messageExtractionService.isValidMessageNumber(messageNumber, totalMessages: extractedMessages.count) else {
            await MainActor.run {
                self.chatMessages.append(ChatMessage(
                    role: .assistant,
                    content: "Invalid message number. Please choose between 1 and \(self.extractedMessages.count).",
                    timestamp: Date()
                ))
                self.isProcessing = false
            }
            return
        }

        let selectedMessageText = extractedMessages[messageNumber - 1]

        do {
            let analysis = try await sentimentAnalysisService.analyzeSentiment(selectedMessageText)

            await MainActor.run {
                self.chatMessages.append(ChatMessage(role: .assistant, content: analysis.analysis, timestamp: Date()))
                self.isProcessing = false
            }

            startListeningForFollowup()
        } catch {
            await MainActor.run {
                self.chatMessages.append(ChatMessage(
                    role: .assistant,
                    content: "Failed to analyze sentiment: \(error.localizedDescription)",
                    timestamp: Date()
                ))
                self.isProcessing = false
            }
            startListeningForFollowup()
        }
    }

    private func handleMessageExtraction(responseText: String) async {
        print("📤 Parsing message list from Gemini's vision response...")
        waitingForMessageExtraction = false

        let messages = messageExtractionService.extractMessages(from: responseText)

        if messages.isEmpty {
            await MainActor.run {
                // Replace the assistant loading bubble with error message
                if let lastIndex = self.chatMessages.lastIndex(where: { $0.role == .assistant && $0.content == "..." }) {
                    self.chatMessages[lastIndex] = ChatMessage(
                        role: .assistant,
                        content: "I couldn't detect any numbered messages in the chat. The response was:\n\(responseText)",
                        timestamp: Date()
                    )
                } else {
                    self.chatMessages.append(ChatMessage(
                        role: .assistant,
                        content: "I couldn't detect any numbered messages in the chat. The response was:\n\(responseText)",
                        timestamp: Date()
                    ))
                }
                self.isProcessing = false
            }
            startListeningForFollowup()
        } else {
            extractedMessages = messages
            waitingForMessageSelection = true

            let messageList = messageExtractionService.formatMessageList(messages)

            await MainActor.run {
                // Replace the assistant loading bubble with message list
                if let lastIndex = self.chatMessages.lastIndex(where: { $0.role == .assistant && $0.content == "..." }) {
                    self.chatMessages[lastIndex] = ChatMessage(
                        role: .assistant,
                        content: "I found \(messages.count) message(s):\n\n\(messageList)\n\nWhich message number would you like me to analyze?",
                        timestamp: Date()
                    )
                } else {
                    self.chatMessages.append(ChatMessage(
                        role: .assistant,
                        content: "I found \(messages.count) message(s):\n\n\(messageList)\n\nWhich message number would you like me to analyze?",
                        timestamp: Date()
                    ))
                }
                self.isProcessing = false
            }

            startListeningForFollowup()
        }
    }

    private func handleNormalResponse(responseText: String) async {
        await MainActor.run {
            self.geminiResponse = responseText
            self.isProcessing = false

            // Replace the assistant loading bubble with actual response
            if let lastIndex = self.chatMessages.lastIndex(where: { $0.role == .assistant && $0.content == "..." }) {
                self.chatMessages[lastIndex] = ChatMessage(role: .assistant, content: responseText, timestamp: Date())
            } else {
                // Fallback: add new message if loading bubble not found
                self.chatMessages.append(ChatMessage(role: .assistant, content: responseText, timestamp: Date()))
            }
        }

        print("✅ Gemini response received")
        startListeningForFollowup()
    }

    private func startListeningForFollowup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Only listen if overlay is actually open with a screenshot
            guard self.capturedScreenshot != nil else {
                print("⚠️ No screenshot, not starting follow-up listener")
                return
            }

            guard !self.chatMessages.isEmpty else {
                print("⚠️ Chat closed, not starting follow-up listener")
                return
            }

            guard !self.isListening else {
                print("⚠️ Already listening")
                return
            }

            print("🎧 Ready for follow-up question...")

            DispatchQueue.main.async {
                self.isListening = true
                self.isListeningForBuffers = true
                self.bufferCount = 0
                print("🎤 Set isListeningForBuffers = true for follow-up")
                // No timeout for follow-up questions
                self.remainingTimeout = nil
            }

            self.voiceInteractionService.startListening(timeout: nil, useExternalAudio: true, onSpeechDetected: { [weak self] in
                DispatchQueue.main.async {
                    // Add placeholder user message bubble immediately on speech detection
                    self?.chatMessages.append(ChatMessage(role: .user, content: "...", timestamp: Date()))
                }
            }, onPartialResult: { [weak self] partialText in
                // Update live transcription in real-time
                DispatchQueue.main.async {
                    self?.liveTranscription = partialText
                }
            }) { [weak self] followupPrompt in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isListening = false
                    self.liveTranscription = "" // Clear live transcription

                    // Replace the loading bubble with actual transcription
                    if let lastIndex = self.chatMessages.lastIndex(where: { $0.role == .user && $0.content == "..." }) {
                        self.chatMessages[lastIndex] = ChatMessage(role: .user, content: followupPrompt, timestamp: Date())
                    }
                }

                // Check for "stop" command (local keyword matching)
                if self.isStopCommand(followupPrompt) {
                    print("🛑 Stop command detected, returning to indicator mode")
                    DispatchQueue.main.async {
                        self.capturedScreenshot = nil
                        self.isProcessing = false
                        self.chatMessages.removeAll()
                    }
                    return
                }

                if followupPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("⚠️ No follow-up question detected, restarting follow-up loop")
                    self.startListeningForFollowup()
                    return
                }

                print("🎤 Follow-up detected: \(followupPrompt)")

                Task {
                    await self.sendTextOnlyToGemini(prompt: followupPrompt)
                }
            }
        }
    }

    // MARK: - Countdown Timer

    private func startCountdownTimer(totalTimeout: TimeInterval) {
        // This is called from main thread already, so no need for async
        print("⏱️ Creating countdown timer for \(totalTimeout)s")

        // Stop any existing timer
        countdownTimer?.invalidate()
        countdownTimer = nil

        // Update countdown every 0.1 seconds for smooth updates
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.timeoutStartTime else {
                return
            }

            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, totalTimeout - elapsed)

            self.remainingTimeout = remaining

            // Stop timer when countdown reaches zero
            if remaining <= 0 {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.remainingTimeout = nil
            }
        }

        print("⏱️ Timer created and scheduled, initial remainingTimeout: \(String(describing: remainingTimeout))")
    }

    private func stopCountdownTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.countdownTimer?.invalidate()
            self?.countdownTimer = nil
            self?.timeoutStartTime = nil
            self?.remainingTimeout = nil
        }
    }
}
