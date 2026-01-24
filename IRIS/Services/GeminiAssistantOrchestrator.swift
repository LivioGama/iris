import Foundation
import AppKit
import AVFoundation
import IRISCore
import IRISNetwork
import IRISMedia
import IRISGaze
import GoogleGenerativeAI
import Combine

// MARK: - ICOI Services
private let intentClassificationService = IntentClassificationService()
private let icoiPromptBuilder = ICOIPromptBuilder()
private let icoiResponseParser = ICOIResponseParser()
private let clipboardService = ClipboardActionService()

// MARK: - Dynamic UI Services
private let dynamicUIPromptBuilder = DynamicUIPromptBuilder()
private let dynamicUIResponseParser = DynamicUIResponseParser()

/// High-level orchestrator for Gemini assistant interactions
/// Responsibility: Workflow coordination ONLY - delegates to specialized services
public class GeminiAssistantOrchestrator: NSObject, ObservableObject, ICOIVoiceCommandDelegate {
    // MARK: - Published Properties
    @Published public var isListening = false
    @Published public var transcribedText = ""
    @Published public var liveTranscription = "" // Real-time partial transcription
    @Published public var geminiResponse = "" // Kept for backward compatibility
    @Published public var liveGeminiResponse = "" // Real-time streaming Gemini response
    @Published public var chatMessages: [ChatMessage] = []
    @Published public var isProcessing = false
    @Published public var isOverlayVisible = false {
        didSet {
            let msg = "🎨 isOverlayVisible changed: \(isOverlayVisible)"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
        }
    } // Independent overlay visibility flag
    @Published public var capturedScreenshot: NSImage? {
        didSet {
            let msg = "📸 capturedScreenshot changed: \(capturedScreenshot != nil ? "SET" : "CLEARED")\n   Callstack: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n   "))"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_blink_debug.log")

            // When screenshot is set, ALWAYS show overlay
            if capturedScreenshot != nil {
                self.isOverlayVisible = true
                print("✅ Screenshot set - overlay is now VISIBLE")
            }
        }
    }
    @Published public var remainingTimeout: TimeInterval? = nil
    @Published public var parsedICOIResponse: ICOIParsedResponse?
    @Published public var currentIntent: ICOIIntent = .general // Current classified intent for UI layout
    @Published public var shouldAutoClose: Bool = false // Trigger for slide-up animation

    // MARK: - Dynamic UI Properties
    @Published public var dynamicUISchema: DynamicUISchema? = nil // AI-generated UI schema
    @Published public var useDynamicUI: Bool = true // Toggle between dynamic UI and classic ICOI modes
    @Published public var demoAllTemplates: Bool = true // When true, shows demo control panel for testing UI templates
    @Published public var autoShowDemoOnLaunch: Bool = false // When true, automatically displays the first demo template on launch
    @Published public var showAllTemplatesShowcase: Bool = true // When true, shows all templates at once in a grid

    // MARK: - Services
    private let geminiClient: GeminiClient
    private let conversationManager: ConversationManager
    internal let voiceInteractionService: VoiceInteractionService
    private let messageExtractionService: MessageExtractionService
    private let screenshotService: ScreenshotService
    private let gazeEstimator: GazeEstimator
    private let sentimentAnalysisService = SentimentAnalysisService.shared
    // private let visionTextDetector = VisionTextDetector() // Commented out for now, VisionTextDetector not found

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
    private let blinkCooldownPeriod: TimeInterval = 5.0  // 5 seconds cooldown to prevent accidental re-opening

    // HARDCODED FLAG: Skip voice input and send this prompt directly
    private let skipVoiceInput = false
    private let hardcodedPrompt = ""

    // Natural overlay state management
    private var isInNaturalMode = false  // Use existing overlay for compatibility

    // Inactivity timeout
    private var inactivityTimer: Timer?
    private var lastActivityTime: Date?
    private let inactivityTimeout: TimeInterval = 10.0  // 10 seconds of no activity

    // Auto-close timer (after Gemini response)
    private var autoCloseTimer: Timer?
    private let autoCloseDelay: TimeInterval = 5.0  // 5 seconds after response completes

    // Prompts
    private let messageExtractionPrompt = "Looking at this chat screenshot, please list all the visible messages you can see in the conversation area (the blue message bubbles on the right side). Number each message (1., 2., 3., etc.). Ignore the contacts list on the left. ONLY list the messages, don't add any other text."

    // MARK: - Initialization
    public init(
        geminiClient: GeminiClient,
        conversationManager: ConversationManager,
        voiceInteractionService: VoiceInteractionService,
        messageExtractionService: MessageExtractionService,
        screenshotService: ScreenshotService,
        gazeEstimator: GazeEstimator
    ) {
        print("🚀🚀🚀 GeminiAssistantOrchestrator init() called - NEW CODE with Gemini 3.0 Flash classification!")
        self.geminiClient = geminiClient
        self.conversationManager = conversationManager
        self.voiceInteractionService = voiceInteractionService
        self.messageExtractionService = messageExtractionService
        self.screenshotService = screenshotService
        self.gazeEstimator = gazeEstimator

        print("🔑 GeminiAssistantOrchestrator initialized with shared client")
        super.init()

        // Set up ICOI voice command delegate
        self.voiceInteractionService.icoiDelegate = self
    }

    // MARK: - Public API
    public func prewarm() {
        voiceInteractionService.prewarm()
    }

    public func handleBlink(at point: CGPoint, focusedElement: DetectedElement?) {
        let msg = "🔵 handleBlink() called at \(point) - chatMessages.count=\(chatMessages.count), screenshot=\(capturedScreenshot != nil), isListening=\(isListening), isProcessing=\(isProcessing)"
        print(msg)
        try? msg.appendLine(to: "/tmp/iris_blink_debug.log")

        // Ignore blinks when overlay is already open (has chat messages or screenshot)
        guard chatMessages.isEmpty && capturedScreenshot == nil else {
            let msg = "⚠️ Overlay already open, ignoring blink"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
            return
        }

        // Prevent concurrent blink handling
        guard !isListening && !isProcessing else {
            let msg = "⚠️ Already processing a blink, skipping"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
            return
        }

        // Cooldown check - prevent rapid re-triggering
        if let lastBlink = lastBlinkTime, Date().timeIntervalSince(lastBlink) < blinkCooldownPeriod {
            let msg = "⚠️ Blink cooldown active, skipping (cooldown: \(blinkCooldownPeriod)s)"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
            return
        }

        lastBlinkTime = Date()
        let msg2 = "🔵 Blink detected at \(point) - PASSED all guards, proceeding to screenshot"
        print(msg2)
        try? msg2.appendLine(to: "/tmp/iris_blink_debug.log")

        // Use the screen where the mouse cursor is (controlled by gaze tracking)
        // This is simpler and doesn't require MainActor isolation
        let mouseLocation = NSEvent.mouseLocation
        guard let gazeScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            let msg = "❌ No screen found at mouse location \(mouseLocation)"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
            self.isProcessing = false
            self.isListening = false
            return
        }

        let message = "✅ Using screen at mouse location \(mouseLocation): \(gazeScreen.frame), capturing screenshot..."
        print(message)
        try? message.appendLine(to: "/tmp/iris_blink_debug.log")

        // Keep existing screenshot flow - we'll enhance it with natural UI
        // Keep the existing system intact

        guard let screenshot = screenshotService.captureScreen(gazeScreen) else {
            print("❌ Failed to capture screenshot")
            self.isProcessing = false
            self.isListening = false
            return
        }

        // Check if screenshot is blank/white - if so, capture mouse location screen instead
        var finalScreenshot = screenshot
        if isBlankScreenshot(screenshot) {
            print("⚠️ Gaze area screenshot is blank, falling back to mouse location screen")
            if let fallbackScreenshot = captureFallbackScreenshot() {
                finalScreenshot = fallbackScreenshot
                print("✅ Using fallback screenshot of mouse location screen")
            } else {
                print("❌ Fallback screenshot also failed, ignoring blink")
                return
            }
        }

        // Note: Bounding box is already visible in the screenshot since we capture
        // the overlay layer. No need to draw it programmatically.
        if let element = focusedElement {
            print("🎯 Captured screenshot with visible highlight for: \(element.label) at \(element.bounds)")
        }

        // DEBUG: Save screenshot to file for debugging
        if let tiffData = finalScreenshot.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let debugPath = "/tmp/iris_debug_screenshot.png"
            try? pngData.write(to: URL(fileURLWithPath: debugPath))
            print("🐛 DEBUG: Saved screenshot to \(debugPath) (size: \(finalScreenshot.size))")
        }

        // Store screenshot and focused element
        self.capturedScreenshot = finalScreenshot
        self.currentFocusedElement = focusedElement

        // Mark activity to start inactivity timer
        markActivity()

        let voiceMsg = "📸 Screenshot stored, about to start voice listening..."
        print(voiceMsg)
        try? voiceMsg.appendLine(to: "/tmp/iris_blink_debug.log")

        // Reset conversation for new interaction
        conversationManager.clearHistory()

        // Clear chat messages
        self.chatMessages.removeAll()

        // HARDCODED FLAG: Skip voice input and send prompt directly
        if skipVoiceInput {
            print("🔧 HARDCODED MODE: Skipping voice input, sending '\(hardcodedPrompt)' directly")
            Task { @MainActor in
                // Add user message to chat
                self.chatMessages.append(ChatMessage(role: .user, content: self.hardcodedPrompt, timestamp: Date()))

                // Classify intent and send to Gemini
                let intentClassification = await intentClassificationService.classifyIntent(input: self.hardcodedPrompt)
                self.currentIntent = intentClassification.intent
                print("📌 Set currentIntent to: \(intentClassification.intent.rawValue)")

                await self.sendToGemini(screenshot: finalScreenshot, prompt: self.hardcodedPrompt, focusedElement: focusedElement)
            }
            return
        }

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

            print("🎤 Calling voiceInteractionService.startListening...")
        }

        voiceInteractionService.startListening(timeout: timeoutDuration, useExternalAudio: true, onSpeechDetected: { [weak self] in
            print("🗣️ Speech detected callback triggered!")
            print("🎤 Speech detected! Stopping countdown and auto-close timer...")
            // Stop countdown and auto-close timer when speech is detected
            DispatchQueue.main.async {
                // Now mark as listening since speech was actually detected
                self?.isListening = true
                self?.isListeningForBuffers = true
                self?.bufferCount = 0
                print("🎤 Set isListening and isListeningForBuffers = true after speech detected")

                self?.countdownTimer?.invalidate()
                self?.countdownTimer = nil
                self?.remainingTimeout = nil

                // Stop auto-close timer since user is speaking
                self?.stopAutoCloseTimer()

                // Don't add placeholder - we have live transcription
            }
        }, onPartialResult: { [weak self] partialText in
            // Update live transcription in real-time
            let msg = "📝 onPartialResult called with: '\(partialText)'"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
            DispatchQueue.main.async {
                self?.liveTranscription = partialText
                self?.markActivity()  // Mark activity when user is speaking
                let msg2 = "📝 liveTranscription set to: '\(partialText)'"
                print(msg2)
                try? msg2.appendLine(to: "/tmp/iris_blink_debug.log")
            }
        }) { [weak self] prompt in
            print("================================================================================")
            print("🚨 VOICE CALLBACK ENTRY - Prompt: '\(prompt)'")
            print("================================================================================")

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

            // Check for "stop" command to exit analysis mode
            if self.isStopCommand(prompt) {
                print("🛑 Stop command detected, returning to indicator mode")
                DispatchQueue.main.async {
                    self.isOverlayVisible = false
                    self.capturedScreenshot = nil
                    self.isProcessing = false
                    self.isListening = false
                    self.chatMessages.removeAll()
                }
                return
            }

            // Only process if there's actual input
            guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("⚠️ No voice input detected (empty prompt) - KEEPING OVERLAY OPEN, waiting for speech")
                // DON'T clear screenshot - keep overlay visible so user can speak
                // The overlay will stay open until user speaks or explicitly closes it
                return
            }

            // CRITICAL: Classify intent synchronously BEFORE showing message
            // Use Task to await classification completion
            NSLog("🔍🔍🔍 ABOUT TO CLASSIFY INTENT for: \"\(prompt)\"")
            Task { @MainActor in
                NSLog("🔍 Task started, calling classifyIntent...")
                let intentClassification = await intentClassificationService.classifyIntent(input: prompt)
                NSLog("🔍 classifyIntent returned: \(intentClassification.intent.rawValue)")

                print("✅ Intent classification completed: \(intentClassification.intent.rawValue) (confidence: \(intentClassification.confidence))")

                // Now that classification is complete, update UI with BOTH intent and message
                self.isListening = false
                self.isListeningForBuffers = false
                self.transcribedText = prompt
                self.liveTranscription = ""

                // Set the intent FIRST
                self.currentIntent = intentClassification.intent
                print("📌 Set currentIntent to: \(intentClassification.intent.rawValue)")

                // Add user message to chat (only once, not duplicate)
                // Check if this exact message already exists to prevent duplicates
                if !self.chatMessages.contains(where: { $0.role == .user && $0.content == prompt }) {
                    self.chatMessages.append(ChatMessage(role: .user, content: prompt, timestamp: Date()))
                    print("✅ Added user message to chat: '\(prompt.prefix(50))...'")
                } else {
                    print("⚠️ User message already exists, skipping duplicate")
                }

                // Send to Gemini (already on MainActor)
                print("✅ Valid prompt received, sending to Gemini with screenshot")
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
            if bufferCount == 1 {
                print("🎤 FIRST AUDIO BUFFER RECEIVED!")
            }
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
            print("🛑 stopListening: Clearing listening state but KEEPING screenshot for overlay")

            // Stop countdown timer directly (no nested async)
            self.countdownTimer?.invalidate()
            self.countdownTimer = nil
            self.timeoutStartTime = nil
            self.remainingTimeout = nil

            self.isListening = false
            self.transcribedText = ""
            // DON'T clear screenshot - keep overlay visible
            // self.capturedScreenshot = nil  // ← Commented out to keep overlay visible
            // DON'T clear chat messages - keep conversation visible
            // self.chatMessages.removeAll()  // ← Commented out

            // Only clear isProcessing if we're not actually processing a Gemini request
            if !self.isProcessing {
                self.geminiResponse = ""
            }
        }

        print("🛑 Listening stopped, ready for new blink")
    }

    /// Resets the entire conversation state including history
    /// Call this when closing the overlay to prevent context bleed between sessions
    public func resetConversationState() {
        let msg = "🔄 Resetting conversation state - CLEARING EVERYTHING"
        print(msg)
        try? msg.appendLine(to: "/tmp/iris_blink_debug.log")

        // CRITICAL: Stop all listening and timers FIRST
        voiceInteractionService.stopListening()

        // Stop countdown timer, inactivity timer, and auto-close timer
        DispatchQueue.main.async {
            self.countdownTimer?.invalidate()
            self.countdownTimer = nil
            self.timeoutStartTime = nil
            self.remainingTimeout = nil
        }

        stopInactivityTimer()
        stopAutoCloseTimer()

        // Set cooldown to prevent immediate reopening
        self.lastBlinkTime = Date()
        let msg2 = "🛑 Stopped all listening/timers and set cooldown"
        print(msg2)
        try? msg2.appendLine(to: "/tmp/iris_blink_debug.log")

        // Clear conversation history in ConversationManager
        conversationManager.clearHistory()

        // Clear all UI state
        DispatchQueue.main.async {
            let msg3 = "🧹 Clearing all UI state including screenshot, chat messages, and flags"
            print(msg3)
            try? msg3.appendLine(to: "/tmp/iris_blink_debug.log")

            self.isOverlayVisible = false
            self.chatMessages.removeAll()
            self.geminiResponse = ""
            self.liveGeminiResponse = ""
            self.transcribedText = ""
            self.liveTranscription = ""
            self.capturedScreenshot = nil
            self.parsedICOIResponse = nil
            self.dynamicUISchema = nil  // Clear dynamic UI schema
            self.isProcessing = false
            self.isListening = false
            self.isListeningForBuffers = false
            self.shouldAutoClose = false

            // Clear extracted messages state
            self.extractedMessages.removeAll()
            self.waitingForMessageSelection = false
            self.waitingForMessageExtraction = false
            self.currentFocusedElement = nil
        }

        print("✅ Conversation state reset complete")
    }

    // MARK: - Auto-Close Management

    /// Starts the auto-close timer (5 seconds after Gemini finishes responding)
    private func startAutoCloseTimer() {
        // Cancel existing timer
        autoCloseTimer?.invalidate()

        print("⏰ Starting auto-close timer (5 seconds)")

        // Start new timer
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: autoCloseDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Check if user has started speaking again or if we're processing
            guard !self.isListening && !self.isProcessing else {
                print("⏰ Auto-close cancelled - user is active")
                return
            }

            print("⏰ Auto-close timer fired - triggering slide-up animation")
            DispatchQueue.main.async {
                self.shouldAutoClose = true
            }
        }
    }

    /// Stops the auto-close timer
    private func stopAutoCloseTimer() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
        print("⏰ Auto-close timer stopped")
    }

    /// Completes the auto-close process after animation finishes
    public func completeAutoClose() {
        print("✅ Auto-close animation complete - resetting conversation state")
        // Reset the flag
        shouldAutoClose = false
        // Now reset everything
        resetConversationState()
    }

    // MARK: - Inactivity Timeout Management

    /// Marks activity to reset the inactivity timer
    private func markActivity() {
        lastActivityTime = Date()

        // Only start/restart timer if overlay is active
        if capturedScreenshot != nil || !chatMessages.isEmpty {
            startInactivityTimer()
        }
    }

    /// Starts the inactivity timer to auto-close overlay after 10 seconds
    private func startInactivityTimer() {
        // Cancel existing timer
        inactivityTimer?.invalidate()

        // Start new timer
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let lastActivity = self.lastActivityTime else {
                return
            }

            let elapsed = Date().timeIntervalSince(lastActivity)

            // Check if we're still inactive (not listening, not processing, no user action)
            let isInactive = !self.isListening && !self.isProcessing

            // If inactive for 10 seconds, close overlay
            if isInactive && elapsed >= self.inactivityTimeout {
                print("⏱️ Inactivity timeout reached (\(elapsed)s) - auto-closing overlay")
                self.autoCloseOverlay()
            }
        }
    }

    /// Stops the inactivity timer
    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        lastActivityTime = nil
    }

    /// Auto-closes the overlay with slide-up animation and reset
    private func autoCloseOverlay() {
        print("🎬 Auto-closing overlay with animation...")

        // Stop the timer
        stopInactivityTimer()

        // Reset conversation state to close overlay
        resetConversationState()
    }

    // MARK: - Public Methods for Demo Mode

    /// Public wrapper for sendToGemini - used by demo mode
    public func sendToGeminiForDemo(screenshot: NSImage, prompt: String) async {
        await sendToGemini(screenshot: screenshot, prompt: prompt, focusedElement: nil)
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

            // Don't add placeholder - we'll use liveGeminiResponse for streaming
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

        // Use the already-classified intent (from transcription completion) and build specialized ICOI prompt
        let currentIntentValue = await MainActor.run { self.currentIntent }
        let useDynamicUIValue = await MainActor.run { self.useDynamicUI }
        let fullPrompt: String

        if useDynamicUIValue {
            // Use dynamic UI system - AI generates custom UI schema
            print("🎨 Using Dynamic UI system")
            fullPrompt = dynamicUIPromptBuilder.buildSystemPrompt() + "\n\n" + dynamicUIPromptBuilder.buildUserPrompt(userRequest: actualPrompt)
        } else if currentIntentValue != .general {
            print("🎯 Using ICOI intent: \(currentIntentValue.rawValue)")
            fullPrompt = icoiPromptBuilder.buildPrompt(for: currentIntentValue, userRequest: actualPrompt, focusedElement: focusedElement)
        } else {
            print("📝 Using general prompt")
            fullPrompt = buildPrompt(actualPrompt: actualPrompt, focusedElement: focusedElement)
        }

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
                    self?.markActivity()  // Mark activity when Gemini is responding
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
            } else if useDynamicUIValue {
                // Parse dynamic UI response
                print("🎨 Handling dynamic UI response...")
                await handleDynamicUIResponse(responseText: responseText)
            } else {
                print("💬 Handling normal response...")
                let currentIntentValue = await MainActor.run { self.currentIntent }
                let intentClassification = IntentClassification(intent: currentIntentValue, confidence: currentIntentValue == .general ? 0.0 : 0.9)
                await handleNormalResponse(responseText: responseText, intentClassification: intentClassification)
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

            // Don't add placeholder - we'll use liveGeminiResponse for streaming
        }

        // Handle message selection
        var actualPrompt = prompt

        // Classify intent for follow-up requests using Gemini Flash
        let intentClassification = await intentClassificationService.classifyIntent(input: prompt)

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
                    self?.markActivity()  // Mark activity when Gemini is responding
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
                await handleNormalResponse(responseText: responseText, intentClassification: intentClassification)
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
            let width = element.bounds.width
            let height = element.bounds.height

            fullPrompt += """


            🎯 FOCUSED REGION (HIGHLIGHTED IN BLUE):
            The screenshot contains a BLUE BOUNDING BOX highlighting the area the user is focused on.

            **Element Details:**
            - Label: "\(element.label)"
            - Type: \(element.type)
            - Bounding Box: x=\(Int(element.bounds.minX)), y=\(Int(element.bounds.minY)), width=\(Int(width)), height=\(Int(height))
            - Center: (\(Int(centerX)), \(Int(centerY)))
            - Confidence: \(String(format: "%.1f%%", element.confidence * 100))

            **CRITICAL INSTRUCTIONS:**
            - The BLUE BORDERED RECTANGLE in the image marks the exact region the user is looking at
            - Focus your primary analysis on the content INSIDE this blue box
            - Use surrounding context to better understand the focused element, but prioritize the highlighted region
            - The user's question pertains specifically to this highlighted area
            """
        }

        fullPrompt += """


        🎯 CRITICAL USER IDENTITY RULES (MESSAGING APPS):
        The USER you are helping is ALWAYS on the RIGHT side of the screen.

        VISUAL IDENTIFICATION:
        - RIGHT side (blue/green bubbles, right-aligned) = THE USER (person you're helping)
        - LEFT side (gray/white bubbles, left-aligned) = THE OTHER PERSON (who sent messages to the user)

        PERSPECTIVE RULES:
        - The USER wants help with THEIR OWN situation and context
        - When the USER asks about sentiment/tone, they mean: "How should I interpret what the OTHER PERSON sent me?"
        - When the USER asks "what should I reply?", they want suggestions for what THEY should write back
        - When the USER asks about a message, they're asking about what was sent TO THEM (from the left side)
        - The conversation is about the USER's life, work, relationships - NOT third-party stories

        🎯 CONTEXT FOCUS:
        - This is ALWAYS about the USER's personal context
        - The USER is seeking help understanding/responding to THEIR OWN conversations
        - Focus on the USER's perspective and circumstances
        - Do NOT discuss third-party situations unless the OTHER PERSON explicitly mentioned them
        - All analysis should be from the USER's point of view

        MESSAGE IDENTIFICATION:
        - Messages on RIGHT = sent BY THE USER (what they already wrote)
        - Messages on LEFT = received FROM THE OTHER PERSON (what they need to respond to)
        - When analyzing sentiment: analyze what the OTHER PERSON (left side) is expressing TO the USER
        - When suggesting replies: suggest what the USER (right side) should write back

        IMPORTANT CONTEXT UNDERSTANDING:
        - Focus on the area the user is looking at (specified above)
        - Answer ANY question ABOUT that area (sentiment, meaning, what to reply, summary, etc.)
        - ALL questions should be answered from the USER's perspective

        VALID QUESTION TYPES (ALL are acceptable and should be answered):
        - "What does this say?" → Describe what the OTHER PERSON sent to the USER
        - "What should I reply?" → Suggest what the USER should write back
        - "What's the sentiment?" → Analyze what the OTHER PERSON is expressing to the USER
        - "Summarize this" → Summarize the conversation from the USER's perspective
        - ANY question about content, emotions, meaning, or suggestions related to the USER's context

        User's voice request: "\(actualPrompt.isEmpty ? "What am I looking at?" : actualPrompt)"

        Response guidelines:
        - CRITICAL: BE EXTREMELY CONCISE - Maximum 1-2 short sentences. Get straight to the point.
        - No explanations, no context, no extra details unless specifically asked
        - Use plain text only - NO markdown, NO asterisks, NO formatting symbols
        - ALWAYS respond from the USER's perspective (right side)
        - When analyzing messages, analyze what was sent TO the USER (from left side)
        - When suggesting replies, suggest what the USER should send (from right side)
        - Focus on the USER's personal situation and context
        - In chats: RIGHT = USER, LEFT = OTHER PERSON (this is absolute and never changes)
        - Example: If asked "what should I reply?", give ONE concise suggestion, not multiple options or explanations
        """

        return fullPrompt
    }

    private func handleMessageSelection(messageNumber: Int) async {
        print("🔢 Message number selected: \(messageNumber)")

        guard messageExtractionService.isValidMessageNumber(messageNumber, totalMessages: extractedMessages.count) else {
            await MainActor.run {
                // Replace loading bubble with error message
                if let lastIndex = self.chatMessages.lastIndex(where: { $0.content == "..." }) {
                    self.chatMessages[lastIndex] = ChatMessage(
                        role: .assistant,
                        content: "Invalid message number. Please choose between 1 and \(self.extractedMessages.count).",
                        timestamp: Date()
                    )
                } else {
                    self.chatMessages.append(ChatMessage(
                        role: .assistant,
                        content: "Invalid message number. Please choose between 1 and \(self.extractedMessages.count).",
                        timestamp: Date()
                    ))
                }
                self.isProcessing = false
            }
            return
        }

        let selectedMessageText = extractedMessages[messageNumber - 1]

        // Filter out timestamps from the message text
        let filteredMessage = filterTimestamps(from: selectedMessageText)

        do {
            let analysis = try await sentimentAnalysisService.analyzeSentiment(filteredMessage)

            await MainActor.run {
                // Replace loading bubble with analysis result
                if let lastIndex = self.chatMessages.lastIndex(where: { $0.content == "..." }) {
                    self.chatMessages[lastIndex] = ChatMessage(
                        role: .assistant,
                        content: analysis.analysis,
                        timestamp: Date()
                    )
                } else {
                    self.chatMessages.append(ChatMessage(role: .assistant, content: analysis.analysis, timestamp: Date()))
                }
                self.isProcessing = false
            }

            startListeningForFollowup()
        } catch {
            await MainActor.run {
                // Replace loading bubble with error message
                if let lastIndex = self.chatMessages.lastIndex(where: { $0.content == "..." }) {
                    self.chatMessages[lastIndex] = ChatMessage(
                        role: .assistant,
                        content: "Failed to analyze sentiment: \(error.localizedDescription)",
                        timestamp: Date()
                    )
                } else {
                    self.chatMessages.append(ChatMessage(
                        role: .assistant,
                        content: "Failed to analyze sentiment: \(error.localizedDescription)",
                        timestamp: Date()
                    ))
                }
                self.isProcessing = false
            }
            startListeningForFollowup()
        }
    }

    /// Filters out timestamps from message text (e.g., "10:30 AM", "14:25", etc.)
    private func filterTimestamps(from text: String) -> String {
        var filtered = text

        // Remove common timestamp patterns
        // Pattern 1: HH:MM AM/PM (e.g., "10:30 AM", "2:45 PM")
        filtered = filtered.replacingOccurrences(
            of: #"\b\d{1,2}:\d{2}\s*[AP]M\b"#,
            with: "",
            options: .regularExpression
        )

        // Pattern 2: 24-hour format (e.g., "14:25", "09:30")
        filtered = filtered.replacingOccurrences(
            of: #"\b\d{1,2}:\d{2}\b"#,
            with: "",
            options: .regularExpression
        )

        // Clean up multiple spaces
        filtered = filtered.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        return filtered.trimmingCharacters(in: .whitespaces)
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

    /// Handles responses from the dynamic UI system - parses both text and UI schema
    private func handleDynamicUIResponse(responseText: String) async {
        print("🎨 handleDynamicUIResponse called")
        print("🎨 Response length: \(responseText.count) chars")
        print("🎨 Response preview: \(String(responseText.prefix(500)))...")
        print("🎨 Contains ui-schema marker: \(responseText.contains("```ui-schema"))")

        // Parse the response to extract text and UI schema
        let parsed = dynamicUIResponseParser.parse(response: responseText)
        let displayText = parsed.text.isEmpty ? responseText : parsed.text

        print("🎨 Parsed text length: \(parsed.text.count)")
        print("🎨 Schema parsed: \(parsed.schema != nil)")

        await MainActor.run {
            self.geminiResponse = displayText
            self.isProcessing = false

            // Replace the assistant loading bubble with actual response
            if let lastIndex = self.chatMessages.lastIndex(where: { $0.role == .assistant && $0.content == "..." }) {
                self.chatMessages[lastIndex] = ChatMessage(role: .assistant, content: displayText, timestamp: Date())
            } else {
                // Fallback: add new message if loading bubble not found
                self.chatMessages.append(ChatMessage(role: .assistant, content: displayText, timestamp: Date()))
            }

            // Store the dynamic UI schema if parsed successfully
            if let schema = parsed.schema {
                self.dynamicUISchema = schema
                print("✅ Dynamic UI schema parsed successfully with \(schema.components.count) components")
            } else {
                print("⚠️ No UI schema found in response, using text-only display")
                self.dynamicUISchema = nil
            }
        }

        // Don't auto-close for dynamic UI - let user interact with the generated interface
        print("⏰ Auto-close timer skipped for dynamic UI (user needs time to interact)")

        startListeningForFollowup()
    }

    private func handleNormalResponse(responseText: String, intentClassification: IntentClassification) async {
        // Parse ICOI responses for specialized intents
        if intentClassification.intent != .general && intentClassification.confidence >= 0.3 {
            let parsedResponse = icoiResponseParser.parse(responseText: responseText, intent: intentClassification.intent)

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

                // Store parsed ICOI response for UI components
                self.parsedICOIResponse = parsedResponse
            }

            print("✅ ICOI response parsed - Intent: \(intentClassification.intent.rawValue), Options: \(parsedResponse.hasOptions), Code: \(parsedResponse.hasCodeBlock)")
        } else {
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
        }

        // Start auto-close timer (5 seconds) - but NOT for code improvement
        // Code improvement needs time to review side-by-side comparison
        if intentClassification.intent != .codeImprovement {
            startAutoCloseTimer()
            print("⏰ Auto-close timer started for intent: \(intentClassification.intent.rawValue)")
        } else {
            print("⏰ Auto-close timer skipped for code improvement (user needs time to review)")
        }

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

            // Add 5-second timeout for follow-up questions
            let followupTimeout: TimeInterval = 5.0

            DispatchQueue.main.async {
                self.isListening = true
                self.isListeningForBuffers = true
                self.bufferCount = 0
                print("🎤 Set isListeningForBuffers = true for follow-up")

                // Set timeout countdown for follow-up
                self.remainingTimeout = followupTimeout
                self.timeoutStartTime = Date()
                self.startCountdownTimer(totalTimeout: followupTimeout)
            }

            self.voiceInteractionService.startListening(timeout: followupTimeout, useExternalAudio: true, onSpeechDetected: { [weak self] in
                DispatchQueue.main.async {
                    // Stop countdown when speech is detected
                    self?.countdownTimer?.invalidate()
                    self?.countdownTimer = nil
                    self?.remainingTimeout = nil

                    // Stop auto-close timer since user is speaking
                    self?.stopAutoCloseTimer()
                    // Don't add placeholder - we have live transcription
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

                    // Stop countdown timer
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                    self.remainingTimeout = nil

                    // Add follow-up user message (check for duplicates)
                    if !self.chatMessages.contains(where: { $0.role == .user && $0.content == followupPrompt }) {
                        self.chatMessages.append(ChatMessage(role: .user, content: followupPrompt, timestamp: Date()))
                        print("✅ Added follow-up user message: '\(followupPrompt.prefix(50))...'")
                    } else {
                        print("⚠️ Follow-up message already exists, skipping duplicate")
                    }
                }

                // Check for "stop" command (local keyword matching)
                if self.isStopCommand(followupPrompt) {
                    print("🛑 Stop command detected, returning to indicator mode")
                    DispatchQueue.main.async {
                        self.isOverlayVisible = false
                        self.capturedScreenshot = nil
                        self.isProcessing = false
                        self.chatMessages.removeAll()
                    }
                    return
                }

                if followupPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("⚠️ No follow-up question detected after 5s timeout - auto-closing overlay")
                    // Instead of restarting the loop, trigger auto-close
                    DispatchQueue.main.async {
                        self.shouldAutoClose = true
                    }
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
                print("⏱️ Timeout reached! KEEPING OVERLAY OPEN, waiting for speech...")
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.remainingTimeout = nil

                // Stop current listening session
                self.voiceInteractionService.stopListening()

                // Reset listening flags but KEEP the overlay open (screenshot stays)
                self.isListening = false
                self.isListeningForBuffers = false
                self.isProcessing = false

                // Keep screenshot and overlay visible - user can still speak
                // Only clear on explicit close or "stop" command
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

    // MARK: - ICOIVoiceCommandDelegate
    public func didReceiveICOICommand(_ command: ICOIVoiceCommand) {
        print("🎯 Handling ICOI voice command: \(command)")

        Task { @MainActor in
            switch command {
            case .useOption(let number):
                if let response = self.parsedICOIResponse,
                   let option = response.numberedOptions.first(where: { $0.number == number }) {
                    // Simulate selecting the option by copying and using it
                    clipboardService.copyOptionContent(option.content)
                    // Could also trigger additional actions here
                }

            case .copyOption(let number):
                if let response = self.parsedICOIResponse,
                   let option = response.numberedOptions.first(where: { $0.number == number }) {
                    clipboardService.copyOptionContent(option.content)
                }

            case .copyCode:
                if let response = self.parsedICOIResponse,
                   let codeBlock = response.codeBlock {
                    clipboardService.copyCodeBlock(language: codeBlock.language, code: codeBlock.code)
                }

            case .exportSummary:
                if let response = self.parsedICOIResponse {
                    let markdown = generateMarkdown(from: response)
                    do {
                        try await clipboardService.exportToFile(content: markdown, suggestedName: "icoi-summary", fileExtension: "md")
                    } catch {
                        print("Failed to export ICOI response: \(error)")
                    }
                }

            case .showMore:
                // Could expand collapsed sections in UI
                print("Show more command received - UI expansion not implemented yet")
            }
        }
    }

    /// Generates markdown representation of ICOI response
    private func generateMarkdown(from response: ICOIParsedResponse) -> String {
        var markdown = ""

        for element in response.elements {
            switch element {
            case .heading(let level, let text):
                let prefix = String(repeating: "#", count: level)
                markdown += "\(prefix) \(text)\n\n"

            case .paragraph(let text):
                markdown += "\(text)\n\n"

            case .bulletList(let items):
                for item in items {
                    markdown += "- \(item)\n"
                }
                markdown += "\n"

            case .numberedOption(let number, let title, let content):
                markdown += "\(number). **\(title)**\n"
                if !content.isEmpty {
                    markdown += "\(content)\n"
                }
                markdown += "\n"

            case .codeBlock(let language, let code):
                markdown += "```\(language)\n\(code)\n```\n\n"

            case .actionItem(let text, let assignee, let completed):
                let checkbox = completed ? "[x]" : "[ ]"
                let assigneeText = assignee.map { " (\($0))" } ?? ""
                markdown += "- \(checkbox) \(text)\(assigneeText)\n"
            }
        }

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBlankScreenshot(_ image: NSImage) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }

        // Sample a small grid of pixels to check if image is mostly white
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0 && height > 0 else { return true }

        let sampleSize = min(100, min(width, height))
        let step = max(1, min(width, height) / sampleSize)

        var whitePixelCount = 0
        var totalSampled = 0

        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return false
        }

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let pixelIndex = (y * width + x) * 4
                if pixelIndex + 2 < CFDataGetLength(data) {
                    let r = bytes[pixelIndex]
                    let g = bytes[pixelIndex + 1]
                    let b = bytes[pixelIndex + 2]

                    // Consider pixel white if all channels are > 250
                    if r > 250 && g > 250 && b > 250 {
                        whitePixelCount += 1
                    }
                    totalSampled += 1
                }
            }
        }

        // If more than 95% of sampled pixels are white, consider it blank
        let whiteRatio = Double(whitePixelCount) / Double(totalSampled)
        return whiteRatio > 0.95
    }

    private func captureFallbackScreenshot() -> NSImage? {
        // Get the screen where the mouse is currently located
        let mouseLocation = NSEvent.mouseLocation

        guard let mouseScreen = NSScreen.screens.first(where: { screen in
            screen.frame.contains(mouseLocation)
        }) else {
            print("⚠️ Could not find screen containing mouse")
            return nil
        }

        print("📸 Capturing fallback screenshot of mouse screen: \(mouseScreen.frame)")

        // Capture the entire screen where the mouse is
        let rect = mouseScreen.frame
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            print("❌ Failed to capture mouse screen")
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
