import Foundation
import AppKit
import Speech
import IRISCore
import IRISVision

public struct GeminiRequest: Codable {
    struct Content: Codable {
        struct Part: Codable {
            let text: String?
            let inlineData: InlineData?

            struct InlineData: Codable {
                let mimeType: String
                let data: String
            }
        }
        let role: String
        let parts: [Part]
    }
    let contents: [Content]
}

public struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

public class GeminiAssistantService: NSObject, ObservableObject {
    @Published public var isListening = false
    @Published public var transcribedText = ""
    @Published public var geminiResponse = "" // Kept for backward compatibility
    @Published public var chatMessages: [ChatMessage] = []
    @Published public var isProcessing = false
    @Published public var capturedScreenshot: NSImage?

    private let apiKey: String
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var lastTranscriptionTime: Date?
    private var silenceCheckTimer: Timer?

    // Deduplication
    private var lastSentPrompt: String = ""
    private var lastSentTime: Date?
    private let deduplicationWindow: TimeInterval = 5.0 // Don't resend same prompt within 5 seconds

    // Conversation history
    private var conversationHistory: [GeminiRequest.Content] = []

    // Message extraction state
    private var extractedMessages: [String] = []
    private var waitingForMessageSelection = false
    private var selectedMessageNumber: Int?
    private var waitingForMessageExtraction = false
    private var currentFocusedElement: DetectedElement? // Store focused element from blink

    // Vision text detector for message extraction
    private let visionTextDetector = VisionTextDetector()

    public override init() {
        // Try to get API key from Keychain first, fallback to environment variable for backwards compatibility
        if let keychainKey = try? KeychainService.shared.getAPIKey() {
            self.apiKey = keychainKey
        } else {
            self.apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        }
        super.init()
    }

    public func handleBlink(at point: CGPoint, focusedElement: DetectedElement?) {
        // Prevent concurrent blink handling
        guard !isListening && !isProcessing else {
            print("⚠️ Already processing a blink, skipping (isListening: \(isListening), isProcessing: \(isProcessing))")
            return
        }

        print("🔵 Blink detected at \(point)")
        print("   State: isListening=\(isListening), isProcessing=\(isProcessing)")

        // Capture screenshot
        guard let screenshot = captureScreenshot() else {
            print("❌ Failed to capture screenshot")
            return
        }

        print("📸 Screenshot captured")

        // Store screenshot and focused element for display and cropping
        DispatchQueue.main.async {
            self.capturedScreenshot = screenshot
            self.currentFocusedElement = focusedElement
        }

        // Reset conversation history for new interaction
        conversationHistory.removeAll()

        // Clear chat messages for new conversation
        DispatchQueue.main.async {
            self.chatMessages.removeAll()
        }

        // Start speech recognition with voice activity detection
        startSpeechRecognition { [weak self] prompt in
            guard let self = self else { return }
            print("🎤 Prompt received: \(prompt)")

            // Only send to Gemini if there's actual voice input
            guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("⚠️ No voice input detected, canceling Gemini request")
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

    private func captureScreenshot() -> NSImage? {
        // Get the screen where the mouse cursor is currently located
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main

        guard let screen = screen else { return nil }
        let rect = screen.frame

        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Crops an image to the focused element bounds
    private func cropImage(_ image: CGImage, to bounds: CGRect, imageSize: CGSize) -> CGImage? {
        print("🔍 Crop input: bounds=\(bounds), imageSize=\(imageSize)")

        // Convert from macOS coordinates (bottom-left origin) to CGImage coordinates (top-left origin)
        // Use the actual captured image height, not screen height
        let flippedY = imageSize.height - bounds.origin.y - bounds.height

        let cropRect = CGRect(
            x: bounds.origin.x,
            y: flippedY,
            width: bounds.width,
            height: bounds.height
        )

        print("📐 Calculated crop rect (before clamp): \(cropRect)")

        // Ensure crop rect is within image bounds
        let validRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))
        guard !validRect.isEmpty else {
            print("⚠️ Crop rect is outside image bounds")
            print("   Requested: \(cropRect), Image size: \(imageSize)")
            return nil
        }

        print("✂️ Final crop rect: \(validRect)")
        let cropped = image.cropping(to: validRect)
        print("✅ Cropped image size: \(cropped?.width ?? 0)x\(cropped?.height ?? 0)")
        return cropped
    }

    private func startSpeechRecognition(completion: @escaping (String) -> Void) {
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startRecording(completion: completion)
                case .denied, .restricted, .notDetermined:
                    print("❌ Speech recognition not authorized")
                    completion("")
                @unknown default:
                    completion("")
                }
            }
        }
    }

    private func startRecording(completion: @escaping (String) -> Void) {
        // Prevent concurrent recordings
        if audioEngine.isRunning {
            print("⚠️ Audio engine already running, skipping")
            completion("")
            return
        }

        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            completion("")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode

        DispatchQueue.main.async {
            self.isListening = true
            // Don't clear transcribedText here - it will be cleared when recording stops
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.lastTranscriptionTime = Date()
                }

                // Start/restart silence detection timer
                self.startSilenceDetection(completion: completion, inputNode: inputNode)
            }

            // Only stop on error - don't stop on isFinal, let silence detection handle it
            if error != nil {
                print("❌ Speech recognition error: \(error!.localizedDescription)")
                self.stopRecordingInternal(completion: completion, inputNode: inputNode)
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            print("🎤 Listening... (will stop automatically after silence)")

            // Don't initialize lastTranscriptionTime - it will be set when user speaks
            // This allows waiting indefinitely for the user to start speaking
            lastTranscriptionTime = nil
            startSilenceDetection(completion: completion, inputNode: inputNode)
        } catch {
            print("❌ Audio engine failed to start: \(error)")
            completion("")
        }
    }

    private func startSilenceDetection(completion: @escaping (String) -> Void, inputNode: AVAudioNode) {
        // Cancel existing timer
        silenceCheckTimer?.invalidate()

        // Check for silence repeatedly every 0.5 seconds
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            // Only stop if we've received some transcription AND been silent for 2.5 seconds
            // lastTranscriptionTime is only set when actual text is transcribed, not at start
            // This allows waiting indefinitely until the user speaks
            if let lastTime = self.lastTranscriptionTime,
               !self.transcribedText.isEmpty,
               Date().timeIntervalSince(lastTime) >= 2.5 {
                print("🔇 Silence detected after speech, stopping recording")
                timer.invalidate()
                self.stopRecordingInternal(completion: completion, inputNode: inputNode)
            }
            // Otherwise, keep checking (waiting for user to speak or still speaking)
        }
    }

    private func stopRecordingInternal(completion: @escaping (String) -> Void, inputNode: AVAudioNode) {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil

        audioEngine.stop()
        inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil

        let capturedText = self.transcribedText

        DispatchQueue.main.async {
            print("🛑 stopRecordingInternal: Setting isListening = false, isProcessing = true, text: '\(capturedText)'")
            self.isListening = false
            self.isProcessing = true // Set processing BEFORE calling completion to prevent overlay disappearing
            self.transcribedText = "" // Clear for next time
            self.lastTranscriptionTime = nil // Reset for next session
            completion(capturedText)
        }
    }

    private func stopRecording() {
        silenceCheckTimer?.invalidate()
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }

    public func stopListening() {
        // Public method to stop listening from UI
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async {
            print("🛑 stopListening: Setting isListening = false, isProcessing = false")
            self.isListening = false
            self.transcribedText = ""
            self.isProcessing = false
            self.lastTranscriptionTime = nil
        }

        print("🛑 Listening stopped, ready for new blink")
    }

    private func startListeningForFollowup() {
        // Wait a bit before starting to listen for follow-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            // Check if chat is still visible (if not, user closed it)
            guard !self.chatMessages.isEmpty else {
                print("⚠️ Chat closed, not starting follow-up listener")
                return
            }

            // Make sure we're not already listening or processing
            guard !self.isListening && !self.isProcessing else {
                print("⚠️ Already listening or processing, skipping follow-up listener")
                return
            }

            print("🎧 Ready for follow-up question...")

            // Start listening for follow-up question
            self.startSpeechRecognition { [weak self] followupPrompt in
                guard let self = self else {
                    print("❌ Self is nil in follow-up callback")
                    return
                }

                print("📥 Follow-up callback received: '\(followupPrompt)'")

                // If user said something, send as follow-up
                if followupPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("⚠️ No follow-up question detected, restarting follow-up loop")
                    // Restart listening loop - never stop
                    self.startListeningForFollowup()
                    return
                }

                print("🎤 Follow-up detected: \(followupPrompt)")

                // Send follow-up as text-only (no screenshot needed for conversation)
                print("💬 Sending text-only follow-up to Gemini...")
                Task {
                    await self.sendTextOnlyToGemini(prompt: followupPrompt)
                }
            }
        }
    }

    public func sendTextOnlyToGemini(prompt: String) async {
        guard !apiKey.isEmpty else {
            await MainActor.run {
                self.geminiResponse = "Error: GEMINI_API_KEY not set."
            }
            return
        }

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
            print("⚙️ sendTextOnlyToGemini: Setting isProcessing = true")
            self.isProcessing = true

            // Add user message to chat UI
            let userChatMessage = ChatMessage(
                role: .user,
                content: prompt,
                timestamp: Date()
            )
            self.chatMessages.append(userChatMessage)
            print("💬 User message added, chat has \(self.chatMessages.count) messages")
        }

        // Check if user is selecting a message number for sentiment analysis
        print("📋 Follow-up state: waitingForMessageSelection=\(waitingForMessageSelection), prompt='\(prompt)'")
        var actualPrompt = prompt

        // If waiting for message selection but user didn't provide a number, reset the state
        if waitingForMessageSelection && SentimentAnalysisService.shared.detectsMessageNumber(in: prompt) == nil {
            print("🔄 User asked a non-number question, resetting message selection state")
            waitingForMessageSelection = false
            extractedMessages.removeAll()
        }

        if waitingForMessageSelection, let messageNumber = SentimentAnalysisService.shared.detectsMessageNumber(in: prompt) {
            print("🔢 Message number selected: \(messageNumber)")

            // Validate message number
            guard messageNumber > 0 && messageNumber <= extractedMessages.count else {
                print("❌ Invalid message number: \(messageNumber) (have \(extractedMessages.count) messages)")

                // Send error response
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

            // Keep waitingForMessageSelection = true so user can select another message
            // It will only be reset when they ask a non-number question

            // Get the selected message text (array is 0-indexed, user selection is 1-indexed)
            let selectedMessageText = extractedMessages[messageNumber - 1]
            print("📝 Selected message text: \(selectedMessageText)")

            // Analyze sentiment using SentimentAnalysisService
            Task {
                do {
                    let analysis = try await SentimentAnalysisService.shared.analyzeSentiment(selectedMessageText)

                    await MainActor.run {
                        self.chatMessages.append(ChatMessage(
                            role: .assistant,
                            content: analysis.analysis,
                            timestamp: Date()
                        ))
                        self.isProcessing = false

                        // Analysis complete - listen for potential new request
                        self.startListeningForFollowup()
                    }
                } catch {
                    print("❌ Sentiment analysis error: \(error)")
                    await MainActor.run {
                        self.chatMessages.append(ChatMessage(
                            role: .assistant,
                            content: "Failed to analyze sentiment: \(error.localizedDescription)",
                            timestamp: Date()
                        ))
                        self.isProcessing = false

                        // Even on error, allow trying again
                        self.startListeningForFollowup()
                    }
                }
            }
            return // Don't continue with normal Gemini flow
        }
        // Check if this is a sentiment analysis request
        else if SentimentAnalysisService.shared.detectsSentimentRequest(in: prompt) {
            print("🎭 Sentiment analysis request detected - using Gemini's vision to read messages directly")

            // Skip local Vision Framework (can't read blue bubble text)
            // Instead, modify prompt to ask Gemini to list visible messages
            actualPrompt = "Looking at this chat screenshot, please list all the visible messages you can see in the conversation area (the blue message bubbles on the right side). Number each message (1., 2., 3., etc.). Ignore the contacts list on the left. ONLY list the messages, don't add any other text."

            // Set flag so we know to parse message list from response
            waitingForMessageExtraction = true

            // Fall through to normal Gemini flow - don't return here
        }

        // Add user's follow-up message to conversation history
        let userMessage = GeminiRequest.Content(
            role: "user",
            parts: [
                GeminiRequest.Content.Part(
                    text: actualPrompt,
                    inlineData: nil
                )
            ]
        )
        conversationHistory.append(userMessage)

        // Create Gemini request with full conversation history
        let request = GeminiRequest(contents: conversationHistory)

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResponse.statusCode == 200 {
                let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

                if let responseText = geminiResponse.candidates.first?.content.parts.first?.text {
                    // Add assistant's response to conversation history
                    let assistantMessage = GeminiRequest.Content(
                        role: "model",
                        parts: [
                            GeminiRequest.Content.Part(
                                text: responseText,
                                inlineData: nil
                            )
                        ]
                    )
                    conversationHistory.append(assistantMessage)

                    // Check if we're waiting for message extraction to send to sentiment API
                    if waitingForMessageExtraction {
                        print("📤 Parsing message list from Gemini's vision response...")
                        waitingForMessageExtraction = false

                        // Parse numbered messages from Gemini's response
                        // Expected format: "1. message text\n2. another message\n3. third message"
                        let lines = responseText.components(separatedBy: .newlines)
                        var messages: [String] = []

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            // Match lines starting with number followed by . or )
                            if let range = trimmed.range(of: "^\\d+[.):]\\s*", options: .regularExpression) {
                                let messageText = trimmed[range.upperBound...].trimmingCharacters(in: .whitespaces)
                                if !messageText.isEmpty {
                                    messages.append(String(messageText))
                                }
                            }
                        }

                        print("📋 Parsed \(messages.count) messages from Gemini's vision")

                        if messages.isEmpty {
                            await MainActor.run {
                                self.chatMessages.append(ChatMessage(
                                    role: .assistant,
                                    content: "I couldn't detect any numbered messages in the chat. The response was:\n\(responseText)",
                                    timestamp: Date()
                                ))
                                self.isProcessing = false
                            }
                            self.startListeningForFollowup()
                        } else {
                            // Store messages and wait for user to select one
                            self.extractedMessages = messages
                            self.waitingForMessageSelection = true

                            await MainActor.run {
                                let messageList = messages.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                                self.chatMessages.append(ChatMessage(
                                    role: .assistant,
                                    content: "I found \(messages.count) message(s):\n\n\(messageList)\n\nWhich message number would you like me to analyze?",
                                    timestamp: Date()
                                ))
                                self.isProcessing = false
                            }

                            // Continue listening for message number selection
                            self.startListeningForFollowup()
                        }
                    } else {
                        // Normal response flow
                        await MainActor.run {
                            self.geminiResponse = responseText
                            self.isProcessing = false

                            // Add assistant message to chat UI
                            let assistantChatMessage = ChatMessage(
                                role: .assistant,
                                content: responseText,
                                timestamp: Date()
                            )
                            self.chatMessages.append(assistantChatMessage)
                        }
                        print("✅ Text-only response received")

                        // Continue listening for more follow-ups
                        self.startListeningForFollowup()
                    }
                } else {
                    await MainActor.run {
                        self.geminiResponse = "No response from Gemini"
                        self.isProcessing = false
                    }
                }
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                await MainActor.run {
                    self.geminiResponse = "Error \(httpResponse.statusCode): \(errorText)"
                    self.isProcessing = false
                }
            }
        } catch {
            await MainActor.run {
                self.geminiResponse = "Error: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }

    private func sendToGemini(screenshot: NSImage, prompt: String, focusedElement: DetectedElement?) async {
        guard !apiKey.isEmpty else {
            await MainActor.run {
                self.geminiResponse = "Error: GEMINI_API_KEY not set. Please set it in your environment."
            }
            print("❌ GEMINI_API_KEY not set")
            return
        }

        // Check for duplicate prompts within deduplication window
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedPrompt == lastSentPrompt.lowercased(),
           let lastTime = lastSentTime,
           Date().timeIntervalSince(lastTime) < deduplicationWindow {
            print("⚠️ Duplicate prompt detected within \(Int(deduplicationWindow))s, skipping to save quota")
            return
        }

        // Update last sent tracking
        lastSentPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSentTime = Date()

        await MainActor.run {
            print("⚙️ sendToGemini: Setting isProcessing = true")
            self.isProcessing = true

            // Add user's initial message to chat UI
            let userChatMessage = ChatMessage(
                role: .user,
                content: prompt,
                timestamp: Date()
            )
            self.chatMessages.append(userChatMessage)
            print("💬 User message added, chat has \(self.chatMessages.count) messages")
        }

        // Check if user is selecting a message number - handle with Vision Framework
        var actualPrompt = prompt

        // If waiting for message selection but user didn't provide a number, reset the state
        if waitingForMessageSelection && SentimentAnalysisService.shared.detectsMessageNumber(in: prompt) == nil {
            print("🔄 User asked a non-number question, resetting message selection state")
            waitingForMessageSelection = false
            extractedMessages.removeAll()
        }

        if waitingForMessageSelection, let messageNumber = SentimentAnalysisService.shared.detectsMessageNumber(in: prompt) {
            print("🔢 Message number selected: \(messageNumber)")

            // Validate message number
            guard messageNumber > 0 && messageNumber <= extractedMessages.count else {
                print("❌ Invalid message number: \(messageNumber) (have \(extractedMessages.count) messages)")

                // Send error response
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

            // Keep waitingForMessageSelection = true so user can select another message
            // It will only be reset when they ask a non-number question

            // Get the selected message text (array is 0-indexed, user selection is 1-indexed)
            let selectedMessageText = extractedMessages[messageNumber - 1]
            print("📝 Selected message text: \(selectedMessageText)")

            // Analyze sentiment using SentimentAnalysisService
            do {
                let analysis = try await SentimentAnalysisService.shared.analyzeSentiment(selectedMessageText)

                await MainActor.run {
                    self.chatMessages.append(ChatMessage(
                        role: .assistant,
                        content: analysis.analysis,
                        timestamp: Date()
                    ))
                    self.isProcessing = false

                    // Analysis complete - listen for potential new request
                    self.startListeningForFollowup()
                }
            } catch {
                print("❌ Sentiment analysis error: \(error)")
                await MainActor.run {
                    self.chatMessages.append(ChatMessage(
                        role: .assistant,
                        content: "Failed to analyze sentiment: \(error.localizedDescription)",
                        timestamp: Date()
                    ))
                    self.isProcessing = false

                    // Even on error, allow trying again
                    self.startListeningForFollowup()
                }
            }
            return // Don't continue with normal Gemini flow
        }
        // Check if this is a sentiment analysis request
        else if SentimentAnalysisService.shared.detectsSentimentRequest(in: prompt) {
            print("🎭 Sentiment analysis request detected - using Gemini's vision to read messages directly")

            // Skip local Vision Framework (can't read blue bubble text)
            // Instead, modify prompt to ask Gemini to list visible messages
            actualPrompt = "Looking at this chat screenshot, please list all the visible messages you can see in the conversation area (the blue message bubbles on the right side). Number each message (1., 2., 3., etc.). Ignore the contacts list on the left. ONLY list the messages, don't add any other text."

            // Set flag so we know to parse message list from response
            waitingForMessageExtraction = true

            // Fall through to normal Gemini flow - don't return here
        }

        // Convert image to JPEG base64
        guard let tiffData = screenshot.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            await MainActor.run {
                self.geminiResponse = "Error: Failed to convert screenshot"
                self.isProcessing = false
            }
            return
        }

        let base64Image = jpegData.base64EncodedString()

        // Build intelligent prompt with context understanding
        var fullPrompt = """
        You are an AI assistant helping a user who is using eye-tracking and voice control.
        """

        if let element = focusedElement {
            // Calculate relative position in the screenshot
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

        // Create initial message with screenshot and prompt
        let initialMessage = GeminiRequest.Content(
            role: "user",
            parts: [
                GeminiRequest.Content.Part(
                    text: fullPrompt,
                    inlineData: nil
                ),
                GeminiRequest.Content.Part(
                    text: nil,
                    inlineData: GeminiRequest.Content.Part.InlineData(
                        mimeType: "image/jpeg",
                        data: base64Image
                    )
                )
            ]
        )

        // Add to conversation history (this is the first message)
        conversationHistory.append(initialMessage)

        // Create Gemini request with conversation history
        let request = GeminiRequest(contents: conversationHistory)

        // Send to Gemini 2.0 Flash
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=\(apiKey)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResponse.statusCode == 200 {
                let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

                if let responseText = geminiResponse.candidates.first?.content.parts.first?.text {
                    // Add assistant's response to conversation history
                    let assistantMessage = GeminiRequest.Content(
                        role: "model",
                        parts: [
                            GeminiRequest.Content.Part(
                                text: responseText,
                                inlineData: nil
                            )
                        ]
                    )
                    conversationHistory.append(assistantMessage)

                    // Check if we're waiting for message extraction to send to sentiment API
                    if waitingForMessageExtraction {
                        print("📤 Parsing message list from Gemini's vision response...")
                        waitingForMessageExtraction = false

                        // Parse numbered messages from Gemini's response
                        // Expected format: "1. message text\n2. another message\n3. third message"
                        let lines = responseText.components(separatedBy: .newlines)
                        var messages: [String] = []

                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            // Match lines starting with number followed by . or )
                            if let range = trimmed.range(of: "^\\d+[.):]\\s*", options: .regularExpression) {
                                let messageText = trimmed[range.upperBound...].trimmingCharacters(in: .whitespaces)
                                if !messageText.isEmpty {
                                    messages.append(String(messageText))
                                }
                            }
                        }

                        print("📋 Parsed \(messages.count) messages from Gemini's vision")

                        if messages.isEmpty {
                            await MainActor.run {
                                self.chatMessages.append(ChatMessage(
                                    role: .assistant,
                                    content: "I couldn't detect any numbered messages in the chat. The response was:\n\(responseText)",
                                    timestamp: Date()
                                ))
                                self.isProcessing = false
                            }
                            self.startListeningForFollowup()
                        } else {
                            // Store messages and wait for user to select one
                            self.extractedMessages = messages
                            self.waitingForMessageSelection = true

                            await MainActor.run {
                                let messageList = messages.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                                self.chatMessages.append(ChatMessage(
                                    role: .assistant,
                                    content: "I found \(messages.count) message(s):\n\n\(messageList)\n\nWhich message number would you like me to analyze?",
                                    timestamp: Date()
                                ))
                                self.isProcessing = false
                            }

                            // Continue listening for message number selection
                            self.startListeningForFollowup()
                        }
                    } else {
                        // Normal Gemini response flow
                        await MainActor.run {
                            self.geminiResponse = responseText
                            self.isProcessing = false

                            // Add assistant message to chat UI
                            let assistantChatMessage = ChatMessage(
                                role: .assistant,
                                content: responseText,
                                timestamp: Date()
                            )
                            self.chatMessages.append(assistantChatMessage)
                            print("💬 Chat now has \(self.chatMessages.count) messages")
                        }
                        print("✅ Gemini response received, overlay should stay open")

                        // Automatically start listening for follow-up
                        print("🎧 Starting follow-up listener...")
                        self.startListeningForFollowup()
                    }
                } else {
                    await MainActor.run {
                        self.geminiResponse = "No response from Gemini"
                        self.isProcessing = false
                    }
                }
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                await MainActor.run {
                    self.geminiResponse = "Error \(httpResponse.statusCode): \(errorText)"
                    self.isProcessing = false
                }
                print("❌ Gemini API error: \(httpResponse.statusCode) - \(errorText)")
            }
        } catch {
            await MainActor.run {
                self.geminiResponse = "Error: \(error.localizedDescription)"
                self.isProcessing = false
            }
            print("❌ Request failed: \(error)")
        }
    }
}
