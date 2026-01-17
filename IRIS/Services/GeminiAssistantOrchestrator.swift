import Foundation
import AppKit
import IRISCore
import IRISNetwork
import IRISMedia
import IRISVision

/// High-level orchestrator for Gemini assistant interactions
/// Responsibility: Workflow coordination ONLY - delegates to specialized services
public class GeminiAssistantOrchestrator: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published public var isListening = false
    @Published public var transcribedText = ""
    @Published public var geminiResponse = "" // Kept for backward compatibility
    @Published public var chatMessages: [ChatMessage] = []
    @Published public var isProcessing = false
    @Published public var capturedScreenshot: NSImage?

    // MARK: - Services
    private let geminiClient: GeminiClient
    private let conversationManager: ConversationManager
    private let voiceInteractionService: VoiceInteractionService
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

    // Prompts
    private let messageExtractionPrompt = "Looking at this chat screenshot, please list all the visible messages you can see in the conversation area (the blue message bubbles on the right side). Number each message (1., 2., 3., etc.). Ignore the contacts list on the left. ONLY list the messages, don't add any other text."

    // MARK: - Initialization
    public override init() {
        // Get API key from Keychain or environment
        let apiKey: String
        if let keychainKey = try? KeychainService.shared.getAPIKey() {
            apiKey = keychainKey
        } else {
            apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        }

        self.geminiClient = GeminiClient(apiKey: apiKey)
        self.conversationManager = ConversationManager(maxHistoryLength: 20)
        self.voiceInteractionService = VoiceInteractionService()
        self.messageExtractionService = MessageExtractionService()
        self.screenshotService = ScreenshotService()

        super.init()
    }

    // MARK: - Public API
    public func handleBlink(at point: CGPoint, focusedElement: DetectedElement?) {
        // Prevent concurrent blink handling
        guard !isListening && !isProcessing else {
            print("⚠️ Already processing a blink, skipping")
            return
        }

        print("🔵 Blink detected at \(point)")

        // Capture screenshot
        guard let screenshot = screenshotService.captureCurrentScreen() else {
            print("❌ Failed to capture screenshot")
            return
        }

        // Store screenshot and focused element
        DispatchQueue.main.async {
            self.capturedScreenshot = screenshot
            self.currentFocusedElement = focusedElement
        }

        // Reset conversation for new interaction
        conversationManager.clearHistory()

        // Clear chat messages
        DispatchQueue.main.async {
            self.chatMessages.removeAll()
        }

        // Start voice interaction with 12-second timeout
        DispatchQueue.main.async {
            self.isListening = true
        }

        voiceInteractionService.startListening(timeout: 12.0) { [weak self] prompt in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isListening = false
                self.transcribedText = prompt
            }

            print("🎤 Prompt received: \(prompt)")

            // Check for "stop" command to exit analysis mode
            let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalizedPrompt == "stop" {
                print("🛑 Stop command detected, returning to indicator mode")
                DispatchQueue.main.async {
                    self.capturedScreenshot = nil
                    self.isProcessing = false
                    self.chatMessages.removeAll()
                }
                return
            }

            // Only process if there's actual input
            guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("⚠️ No voice input detected")
                DispatchQueue.main.async {
                    self.capturedScreenshot = nil
                    self.isProcessing = false
                }
                return
            }

            // Send to Gemini
            Task {
                await self.sendToGemini(screenshot: screenshot, prompt: prompt, focusedElement: focusedElement)
            }
        }
    }

    public func stopListening() {
        voiceInteractionService.stopListening()

        DispatchQueue.main.async {
            print("🛑 stopListening: Setting isListening = false, isProcessing = false")
            self.isListening = false
            self.transcribedText = ""
            self.isProcessing = false
        }

        print("🛑 Listening stopped, ready for new blink")
    }

    // MARK: - Private Methods
    private func sendToGemini(screenshot: NSImage, prompt: String, focusedElement: DetectedElement?) async {
        // Check for duplicate prompts
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
            self.chatMessages.append(ChatMessage(role: .user, content: prompt, timestamp: Date()))
        }

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

        // Create Gemini request
        let initialMessage = GeminiRequest.Content(
            role: "user",
            parts: [
                GeminiRequest.Content.Part(text: fullPrompt, inlineData: nil),
                GeminiRequest.Content.Part(
                    text: nil,
                    inlineData: GeminiRequest.Content.Part.InlineData(mimeType: "image/jpeg", data: base64Image)
                )
            ]
        )

        conversationManager.addMessage(initialMessage)

        let request = GeminiRequest(contents: conversationManager.getHistory())

        // Send request
        do {
            let response = try await geminiClient.sendRequest(request)

            guard let responseText = response.candidates.first?.content.parts.first?.text else {
                throw GeminiError.noResponse
            }

            // Add response to history
            let assistantMessage = GeminiRequest.Content(
                role: "model",
                parts: [GeminiRequest.Content.Part(text: responseText, inlineData: nil)]
            )
            conversationManager.addMessage(assistantMessage)

            // Handle message extraction flow
            if waitingForMessageExtraction {
                await handleMessageExtraction(responseText: responseText)
            } else {
                await handleNormalResponse(responseText: responseText)
            }

        } catch {
            await MainActor.run {
                self.geminiResponse = "Error: \(error.localizedDescription)"
                self.isProcessing = false
            }
            print("❌ Request failed: \(error)")
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
            self.chatMessages.append(ChatMessage(role: .user, content: prompt, timestamp: Date()))
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
        let userMessage = GeminiRequest.Content(
            role: "user",
            parts: [GeminiRequest.Content.Part(text: actualPrompt, inlineData: nil)]
        )
        conversationManager.addMessage(userMessage)

        let request = GeminiRequest(contents: conversationManager.getHistory())

        do {
            let response = try await geminiClient.sendRequest(request)

            guard let responseText = response.candidates.first?.content.parts.first?.text else {
                throw GeminiError.noResponse
            }

            let assistantMessage = GeminiRequest.Content(
                role: "model",
                parts: [GeminiRequest.Content.Part(text: responseText, inlineData: nil)]
            )
            conversationManager.addMessage(assistantMessage)

            if waitingForMessageExtraction {
                await handleMessageExtraction(responseText: responseText)
            } else {
                await handleNormalResponse(responseText: responseText)
            }

        } catch {
            await MainActor.run {
                self.geminiResponse = "Error: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }

    // MARK: - Helper Methods
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
                self.chatMessages.append(ChatMessage(
                    role: .assistant,
                    content: "I couldn't detect any numbered messages in the chat. The response was:\n\(responseText)",
                    timestamp: Date()
                ))
                self.isProcessing = false
            }
            startListeningForFollowup()
        } else {
            extractedMessages = messages
            waitingForMessageSelection = true

            let messageList = messageExtractionService.formatMessageList(messages)

            await MainActor.run {
                self.chatMessages.append(ChatMessage(
                    role: .assistant,
                    content: "I found \(messages.count) message(s):\n\n\(messageList)\n\nWhich message number would you like me to analyze?",
                    timestamp: Date()
                ))
                self.isProcessing = false
            }

            startListeningForFollowup()
        }
    }

    private func handleNormalResponse(responseText: String) async {
        await MainActor.run {
            self.geminiResponse = responseText
            self.isProcessing = false
            self.chatMessages.append(ChatMessage(role: .assistant, content: responseText, timestamp: Date()))
        }

        print("✅ Gemini response received")
        startListeningForFollowup()
    }

    private func startListeningForFollowup() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            guard !self.chatMessages.isEmpty else {
                print("⚠️ Chat closed, not starting follow-up listener")
                return
            }

            guard !self.isListening && !self.isProcessing else {
                print("⚠️ Already listening or processing")
                return
            }

            print("🎧 Ready for follow-up question...")

            DispatchQueue.main.async {
                self.isListening = true
            }

            self.voiceInteractionService.startListening(timeout: nil) { [weak self] followupPrompt in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isListening = false
                }

                // Check for "stop" command
                let normalizedFollowup = followupPrompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normalizedFollowup == "stop" {
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
}
