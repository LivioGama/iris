import Foundation
import AppKit
import AVFoundation
import IRISCore
import IRISNetwork
import IRISMedia
import IRISGaze
import GoogleGenerativeAI
import Combine

public enum VoiceAgentState: String {
    case idle
    case userSpeaking
    case modelSpeaking
    case toolRunning
    case analyzing  // When generating proactive suggestions or analyzing context
}

// MARK: - ICOI Services
private let intentClassificationService = IntentClassificationService()
private let icoiPromptBuilder = ICOIPromptBuilder()
private let icoiResponseParser = ICOIResponseParser()
private let clipboardService = ClipboardActionService()

// MARK: - Dynamic UI Services
private let dynamicUIPromptBuilder = DynamicUIPromptBuilder()
private let dynamicUIResponseParser = DynamicUIResponseParser()

// MARK: - Proactive Intent Services
private let proactiveIntentPromptBuilder = ProactiveIntentPromptBuilder()

// MARK: - Skills Services
private let skillRegistry = SkillRegistry.shared
private let skillLoader = SkillLoader.shared
private let actionExecutor = ActionExecutor.shared
private let actionPlanner = ActionPlanner.shared

/// High-level orchestrator for Gemini assistant interactions
/// Responsibility: Workflow coordination ONLY - delegates to specialized services
public class GeminiAssistantOrchestrator: NSObject, ObservableObject, ICOIVoiceCommandDelegate, AIProvider {
    // MARK: - Voice Agent State
    @Published public var voiceAgentState: VoiceAgentState = .idle
    private let audioPlaybackService = AudioPlaybackService()
    private let latencyTracker = LatencyTracker.shared

    // MARK: - Published Properties
    @Published public var isListening = false
    @Published public var isGlobalPauseActive = false
    @Published public var transcribedText = ""
    @Published public var liveTranscription = "" // Real-time partial transcription
    @Published public var geminiResponse = "" // Kept for backward compatibility
    @Published public var liveGeminiResponse = "" // Real-time streaming Gemini response
    @Published public var audioQueue: [Data] = []
    @Published public var isPlayingAudio = false

    /// Current tool being executed by the agent
    @Published public var currentTool: (name: String, args: [String: Any])?

    @Published public var chatMessages: [ChatMessage] = []
    @Published public var isProcessing = false
    @Published public var isOverlayVisible = false {
        didSet {
            let msg = "🎨 isOverlayVisible changed: \(isOverlayVisible)"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
        }
    }
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
    @Published public var demoAllTemplates: Bool = false // When true, shows demo control panel for testing UI templates
    @Published public var autoShowDemoOnLaunch: Bool = false // When true, automatically displays the first demo template on launch
    @Published public var showAllTemplatesShowcase: Bool = false // When true, shows all templates at once in a grid

    // MARK: - AIProvider Conformance
    public var responsePublisher: AnyPublisher<String, Never> {
        $liveGeminiResponse.eraseToAnyPublisher()
    }

    // MARK: - Services
    private let geminiClient: GeminiClient
    private let geminiAudioClient: GeminiAudioClient
    private let geminiLiveClient: GeminiLiveClient
    private let conversationManager: ConversationManager
    internal let voiceInteractionService: VoiceInteractionService
    private let messageExtractionService: MessageExtractionService
    private let screenshotService: ScreenshotService
    private let gazeEstimator: GazeEstimator
    private let sentimentAnalysisService = SentimentAnalysisService.shared
    private let continuousScreenCapture: ContinuousScreenCaptureService
    private let cameraService: CameraService
    private let audioStreamEncoder: AudioStreamEncoder

    // MARK: - Live Session State
    @Published public private(set) var isLiveSessionActive = false
    private var isStreamingAudio = false
    private var isToolExecuting = false  // Pause audio during tool execution to prevent server cancellation
    private var isWarmingUp = false  // Suppresses primer turn output
    private var accumulatedLiveText = ""
    private var frameSendTimer: Timer?
    private let frameSendInterval: TimeInterval = 2.0  // Send screen frame every 2 seconds while idle
    private var lastAudioChunkLogTime: Date?
    private var frameSendCount = 0
    private var lastProactiveCheckTime: Date = .distantPast
    private let proactiveCheckCooldown: TimeInterval = 20.0  // Check every 20s when idle on a chat app
    private var suppressModelAudioUntilTurnComplete = false
    private var isProactiveCheckInProgress = false  // Suppresses text/audio from proactive checks
    private let verboseLogsEnabled = ProcessInfo.processInfo.environment["IRIS_VERBOSE_LOGS"] == "1"

    // MARK: - Wake Word
    @Published public var wakeWordRequired: Bool = UserDefaults.standard.object(forKey: "IRIS_WAKE_WORD_REQUIRED") as? Bool ?? false {
        didSet { UserDefaults.standard.set(wakeWordRequired, forKey: "IRIS_WAKE_WORD_REQUIRED") }
    }
    public let wakeWord = "iris"
    private var wakeWordDetectedThisTurn = false

    // MARK: - State
    private var extractedMessages: [String] = []
    private var waitingForMessageSelection = false
    private var waitingForMessageExtraction = false
    private var currentFocusedElement: DetectedElement?

    // Countdown timer
    private var countdownTimer: Timer?
    private var timeoutStartTime: Date?

    // Restored for protocol conformance and dependency resolution
    private var lastBlinkTime: Date?
    private let blinkCooldownPeriod: TimeInterval = 1.0
    public var onBlinkDetected: ((CGPoint, DetectedElement?) -> Void)?

    // Legacy state properties restored to fix compilation in other parts of the system
    @Published public var proactiveSuggestions: [ProactiveSuggestion] = []
    @Published public var isAnalyzingScreenshot: Bool = false
    @Published public var detectedContext: String = ""
    @Published public var currentMatchedSkill: Skill?
    @Published public var isExecutingSkill: Bool = false
    @Published public var executionProgress: String = ""
    @Published public var showExecutionConfirmation: Bool = false
    @Published public var lastExecutionResult: ExecutionResult?
    @Published public var pendingActionPlan: ActionPlan?

    // MARK: - Debug State (for overlay display)
    @Published public var debugVoiceStartTime: Date?
    @Published public var debugVoiceEndTime: Date?
    @Published public var debugGeminiRequestTime: Date?
    @Published public var debugGeminiResponseTime: Date?
    @Published public var debugLastEvent: String = ""
    @Published public var statusLog: [String] = []  // Rolling log for status console
    private let statusLogMax = 6

    /// Append a line to the rolling status log (main-thread safe)
    public func logStatus(_ message: String) {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let line = "\(df.string(from: Date())) \(message)"
        statusLog.append(line)
        if statusLog.count > statusLogMax { statusLog.removeFirst() }
        debugLastEvent = message
    }

    // Deduplication state
    private var lastSentPrompt: String = ""
    private var lastSentTime: Date?
    private let deduplicationWindow: TimeInterval = 1.0

    // Missing Skill matching methods added as stubs
    private func parseExecutionCommandStub(_ input: String) -> String? { return nil }
    private func stopAllListening() { stopListening() }

    // Global hotkey monitor for Control+I (toggle tracking + listening)
    private var hotkeyMonitor: Any?
    private var globalPauseWasTrackingEnabled = true

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
        geminiAudioClient: GeminiAudioClient,
        geminiLiveClient: GeminiLiveClient,
        conversationManager: ConversationManager,
        voiceInteractionService: VoiceInteractionService,
        messageExtractionService: MessageExtractionService,
        screenshotService: ScreenshotService,
        gazeEstimator: GazeEstimator,
        continuousScreenCapture: ContinuousScreenCaptureService,
        cameraService: CameraService,
        audioStreamEncoder: AudioStreamEncoder
    ) {
        print("🚀🚀🚀 GeminiAssistantOrchestrator init() called - Live API + Continuous Capture")
        self.geminiClient = geminiClient
        self.geminiAudioClient = geminiAudioClient
        self.geminiLiveClient = geminiLiveClient
        self.conversationManager = conversationManager
        self.voiceInteractionService = voiceInteractionService
        self.messageExtractionService = messageExtractionService
        self.screenshotService = screenshotService
        self.gazeEstimator = gazeEstimator
        self.continuousScreenCapture = continuousScreenCapture
        self.cameraService = cameraService
        self.audioStreamEncoder = audioStreamEncoder

        print("🔑 GeminiAssistantOrchestrator initialized with Live API client")
        super.init()

        // Set up ICOI voice command delegate
        self.voiceInteractionService.icoiDelegate = self

        // Loop 2: Bind audio buffers to the encoder for streaming
        // Always forward mic to Gemini — Gemini's server-side VAD handles turn-taking.
        // Echo cancellation is handled by stopping playback on user interruption (inputTranscription).
        self.voiceInteractionService.onAudioBuffer = { [weak self] buffer in
            guard let self = self, self.isLiveSessionActive else { return }
            self.audioStreamEncoder.processBuffer(buffer)
        }

        // Wire up Live API response handling
        setupLiveClientCallbacks()

        // Setup audio playback for model responses
        setupAudioPlayback()
    }

    private func setupAudioPlayback() {
        do {
            try audioPlaybackService.setup(sampleRate: 24000, channels: 1)
            audioPlaybackService.onPlaybackStarted = { [weak self] in
                self?.latencyTracker.markAudioPlayed()
            }
            audioPlaybackService.onPlaybackStopped = { [weak self] in
                if self?.voiceAgentState == .modelSpeaking {
                    self?.voiceAgentState = .idle
                }
            }
        } catch {
            print("❌ Failed to setup audio playback: \(error)")
        }
    }

    // MARK: - Public API
    public func prewarm() {
        voiceInteractionService.prewarm()
    }

    // MARK: - Live Session API

    /// Sets up callbacks from the GeminiLiveClient
    private func setupLiveClientCallbacks() {
        geminiLiveClient.onStateChange = { [weak self] state in
            let msg = "🔄 GeminiLiveClient state: \(state.rawValue)"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_live_debug.log")
            Task { @MainActor in
                guard let self = self else { return }
                switch state {
                case .sessionReady:
                    let msg = "✅ Live session ready — continuous streaming active"
                    print(msg)
                    try? msg.appendLine(to: "/tmp/iris_live_debug.log")
                    self.isLiveSessionActive = true

                    // PRE-WARM: Send first screen frame immediately to reduce first-response latency
                    if let frame = self.continuousScreenCapture.latestFrame {
                        self.geminiLiveClient.sendImageFrame(frame.jpegBase64)
                        let warmMsg = "🔥 Pre-warm: sent initial screen frame immediately"
                        print(warmMsg)
                        try? warmMsg.appendLine(to: "/tmp/iris_live_debug.log")
                    }
                    // Send a silent context primer so the model is warmed up for the first real query
                    self.isWarmingUp = true
                    self.geminiLiveClient.sendTextMessage("Session started. You are now seeing my screen. Await my voice.")
                    self.logStatus("live session ready")
                case .disconnected:
                    self.logStatus("disconnected")
                    self.isLiveSessionActive = false
                    self.isStreamingAudio = false
                default:
                    break
                }
            }
        }

        geminiLiveClient.onResponse = { [weak self] responseType in
            Task { @MainActor in
                guard let self = self else { return }
                switch responseType {
                case .text(let text):
                    if self.isWarmingUp || self.isProactiveCheckInProgress { return }
                    if self.wakeWordRequired && !self.wakeWordDetectedThisTurn { return }
                    // Direct text from model (rare in AUDIO mode, but handle it)
                    self.accumulatedLiveText += text
                    self.liveGeminiResponse = self.accumulatedLiveText
                    let msg = "💬 Live API text: \(text.prefix(100))"
                    print(msg)
                    try? msg.appendLine(to: "/tmp/iris_live_debug.log")
                case .outputTranscription(let transcript):
                    if self.isWarmingUp || self.isProactiveCheckInProgress { return }
                    if self.wakeWordRequired && !self.wakeWordDetectedThisTurn { return }
                    // Transcription of model's audio response — incremental chunks, APPEND
                    self.accumulatedLiveText += transcript
                    self.liveGeminiResponse = self.accumulatedLiveText
                    self.debugGeminiResponseTime = Date()
                    self.logStatus("model responding")
                    if self.verboseLogsEnabled {
                        let msg = "📝 Live API output transcription (APPEND): \(transcript.prefix(100))"
                        print(msg)
                        try? msg.appendLine(to: "/tmp/iris_live_debug.log")
                    }
                case .inputTranscription(let transcript):
                    // Transcription of user's speech — incremental chunks, APPEND
                    self.liveTranscription += transcript
                    self.voiceAgentState = .userSpeaking
                    self.logStatus("user speaking")
                    // Wake word detection: check cumulative transcription
                    if !self.wakeWordDetectedThisTurn {
                        let lower = self.liveTranscription.lowercased()
                        let wakeVariants = ["iris", "i.r.i.s", "i wish", "i risk", "aris", "aeris", "ires", "irise", "irish", "ayris"]
                        if wakeVariants.contains(where: { lower.contains($0) }) {
                            self.wakeWordDetectedThisTurn = true
                            try? "🔑 Wake word detected in: \(self.liveTranscription.prefix(80))".appendLine(to: "/tmp/iris_live_debug.log")
                        }
                    }
                    // User is interrupting — stop model audio so mic doesn't echo it
                    if self.audioPlaybackService.isPlaying {
                        self.audioPlaybackService.stop()
                        self.suppressModelAudioUntilTurnComplete = true
                    }
                    if self.verboseLogsEnabled {
                        let msg = "🎤 Live API input transcription: \(transcript.prefix(100))"
                        print(msg)
                        try? msg.appendLine(to: "/tmp/iris_live_debug.log")
                    }
                case .audio(let audioData):
                    // Suppress audio during warm-up primer or proactive check
                    if self.isWarmingUp || self.isProactiveCheckInProgress { return }
                    // Wake word gate: no audio if user didn't say "IRIS"
                    if self.wakeWordRequired && !self.wakeWordDetectedThisTurn { return }
                    if self.suppressModelAudioUntilTurnComplete {
                        if self.verboseLogsEnabled {
                            let msg = "🔇 Suppressing model audio chunk (manual interrupt active)"
                            print(msg)
                            try? msg.appendLine(to: "/tmp/iris_live_debug.log")
                        }
                        return
                    }
                    self.latencyTracker.markChunkReceived()
                    self.audioPlaybackService.enqueue(audioData)
                    if self.voiceAgentState != .modelSpeaking {
                        self.voiceAgentState = .modelSpeaking
                        self.latencyTracker.markAudioPlayed()
                    }
                case .turnComplete:
                    self.suppressModelAudioUntilTurnComplete = false
                    // If this was a proactive check turn, silently discard
                    if self.isProactiveCheckInProgress {
                        self.isProactiveCheckInProgress = false
                        self.accumulatedLiveText = ""
                        self.liveGeminiResponse = ""
                        return
                    }
                    // If this is the warm-up primer turn, silently discard and mark ready
                    if self.isWarmingUp {
                        self.isWarmingUp = false
                        self.accumulatedLiveText = ""
                        self.liveGeminiResponse = ""
                        self.liveTranscription = ""
                        self.logStatus("model warmed up")
                        return
                    }
                    self.logStatus("turn complete")
                    self.handleLiveTurnComplete()
                case .toolCall(let name, let args, let responseId):
                    // Tool calls from proactive checks always pass through
                    let isProactive = self.isProactiveCheckInProgress
                    self.isProactiveCheckInProgress = false
                    // Wake word gate: block tool calls from non-wake-word speech (but allow proactive)
                    if self.wakeWordRequired && !self.wakeWordDetectedThisTurn && !isProactive {
                        try? "🔇 Wake word gate blocked tool call: \(name)".appendLine(to: "/tmp/iris_live_debug.log")
                        // Send empty response so Gemini doesn't hang
                        self.geminiLiveClient.sendToolResponse(responseId: responseId, name: name, result: ["status": "blocked_no_wake_word"])
                        return
                    }
                    self.logStatus("tool: \(name)")
                    self.voiceAgentState = .toolRunning
                    self.isToolExecuting = true  // Pause audio to prevent server cancellation
                    self.currentTool = (name: name, args: args)
                    try? "🔧 Tool call: \(name)".appendLine(to: "/tmp/iris_live_debug.log")
                    Task {
                        let result = await self.executeLiveTool(name: name, args: args)
                        self.currentTool = nil
                        self.isToolExecuting = false  // Resume audio
                        self.geminiLiveClient.sendToolResponse(responseId: responseId, name: name, result: ["output": result])
                        self.voiceAgentState = .modelSpeaking // Assuming model continues
                    }
                }
            }
        }

        geminiLiveClient.onDisconnect = { [weak self] error in
            let msg = "🔌 Live session onDisconnect: \(error?.localizedDescription ?? "clean")"
            print(msg)
            try? msg.appendLine(to: "/tmp/iris_live_debug.log")
            Task { @MainActor in
                guard let self = self else { return }
                self.isLiveSessionActive = false
                self.isStreamingAudio = false

                // Auto-reconnect after 3 seconds if we didn't intentionally stop
                let timerActive = self.frameSendTimer != nil
                let reconnectDebug = "🔄 Reconnect check: frameSendTimer=\(timerActive ? "active" : "nil")"
                print(reconnectDebug)
                try? reconnectDebug.appendLine(to: "/tmp/iris_live_debug.log")

                // Always reconnect unless stopLiveSession was called (which nils the timer)
                if timerActive {
                    self.logStatus("reconnecting in 3s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        guard let self = self else { return }
                        self.logStatus("reconnecting...")
                        self.geminiLiveClient.connect()
                        // Restart frame timer if it died
                        if self.frameSendTimer == nil {
                            self.startFrameSendTimer()
                        }
                    }
                }
            }
        }

        // Wire audio encoder output to Live API — always send when session is active.
        // Pause during tool execution to prevent server from cancelling tool calls.
        audioStreamEncoder.onEncodedChunk = { [weak self] base64Chunk in
            guard let self = self, self.isLiveSessionActive else { return }
            guard !self.isToolExecuting else { return }
            self.geminiLiveClient.sendAudioChunk(base64Chunk)
            // Log periodically (not every chunk to avoid spam)
            let now = Date()
            if self.lastAudioChunkLogTime == nil || now.timeIntervalSince(self.lastAudioChunkLogTime!) > 30.0 {
                self.lastAudioChunkLogTime = now
                let msg = "🔊 Sending audio chunk to Live API (size: \(base64Chunk.count) chars)"
                print(msg)
                try? msg.appendLine(to: "/tmp/iris_live_debug.log")
            }
        }
    }

    /// Start the live session: connect WebSocket, start continuous screen capture,
    /// and begin periodically sending screen frames to Gemini Live API.
    /// Audio is always streamed via the encoder — Gemini handles turn detection server-side.
    public func startLiveSession() {
        guard !isLiveSessionActive else {
            print("⚠️ Live session already active")
            return
        }

        print("🚀 Starting live session (continuous screen sharing + audio)...")
        try? "🚀 Starting live session \(Date())".write(toFile: "/tmp/iris_live_debug.log", atomically: true, encoding: .utf8)
        accumulatedLiveText = ""

        // Connect WebSocket
        geminiLiveClient.connect()

        // Start continuous screen capture
        Task {
            do {
                try await continuousScreenCapture.start()
                print("✅ Continuous screen capture started")
            } catch {
                print("❌ Failed to start continuous capture: \(error.localizedDescription)")
            }
        }

        // NOTE: Camera capture disabled - gaze tracking already uses the MacBook camera
        // Only screen frames are sent to Gemini Live API

        // Loop 1 & 2: Start continuous audio capture
        // We pass handleVoiceStart to enable local barge-in (interrupt playback immediately)
        voiceInteractionService.startListening(
            timeout: nil,
            useExternalAudio: false,
            onSpeechDetected: { [weak self] in
                print("🗣️ Loop 1: Speech detected locally - triggering barge-in")
                self?.handleVoiceStart()
            },
            onPartialResult: nil,
            completion: { _ in }
        )

        // Start periodic idle frame sending for persistent screen context.
        startFrameSendTimer()

        // Setup global hotkey listener for Control+I (toggle gaze tracking)
        setupGlobalHotkey()
    }

    /// Starts a repeating timer that sends the latest screen frame to Gemini Live API
    private func startFrameSendTimer() {
        frameSendTimer?.invalidate()
        frameSendCount = 0
        frameSendTimer = Timer.scheduledTimer(withTimeInterval: frameSendInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isLiveSessionActive else {
                return
            }

            // OPTIMIZATION: Do not send frames while we are already in an active turn
            // (user speaking, model speaking, or processing). The high-res snapshot
            // sent at handleVoiceStart() is sufficient context for the current turn.
            guard self.voiceAgentState == .idle && !self.isProcessing else {
                return
            }

            // Send only screen frames - camera is used exclusively by gaze tracking
            if let frame = self.continuousScreenCapture.latestFrame {
                // Update gaze point for screen capture overlay before sending
                let gazePoint = MainActor.assumeIsolated { self.gazeEstimator.gazePoint }
                self.continuousScreenCapture.gazePoint = gazePoint

                self.geminiLiveClient.sendImageFrame(frame.jpegBase64)
                self.frameSendCount += 1
                self.maybeTriggerProactiveReplyCheck()

                if self.verboseLogsEnabled && (self.frameSendCount <= 4 || self.frameSendCount % 20 == 0) {
                    let msg = "📹 Sent idle background frame #\(self.frameSendCount) to Live API (jpeg size: \(frame.jpegBase64.count) chars)"
                    print(msg)
                    try? msg.appendLine(to: "/tmp/iris_live_debug.log")
                }
            } else if self.verboseLogsEnabled {
                let msg = "⚠️ Frame timer tick but no screen frame in buffer"
                print(msg)
                try? msg.appendLine(to: "/tmp/iris_live_debug.log")
            }
        }
        print("📹 Frame send timer started (every \(frameSendInterval)s)")
    }

    /// Stop the live session
    public func stopLiveSession() {
        print("🛑 Stopping live session...")
        frameSendTimer?.invalidate()
        frameSendTimer = nil
        geminiLiveClient.disconnect()
        voiceInteractionService.stopListening()
        continuousScreenCapture.stop()
        // Camera not started, no need to stop
        audioStreamEncoder.reset()
        isLiveSessionActive = false
        isStreamingAudio = false
        accumulatedLiveText = ""

        // Remove global hotkey monitor
        removeGlobalHotkey()
    }

    /// Update the preferred screen for continuous screen capture
    public func setContinuousScreenCaptureScreen(_ screen: NSScreen?) {
        continuousScreenCapture.preferredScreen = screen
        print("📹 Updated continuous screen capture to: \(screen?.localizedName ?? "nil")")
    }

    // MARK: - Global Hotkey for Tracking + Listening Toggle

    private func setupGlobalHotkey() {
        removeGlobalHotkey()

        // keyCode 34 = 'i'
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if event.keyCode == 34 && event.modifierFlags.contains(.control) {
                Task { @MainActor in
                    self.toggleTrackingAndListening()
                }
            }
        }

        try? "⌨️ Global hotkey Control+I registered (toggle tracking + listening)".appendLine(to: "/tmp/iris_live_debug.log")
    }

    private func removeGlobalHotkey() {
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitor = nil
        }
    }

    @MainActor
    private func toggleTrackingAndListening() {
        let newPaused = !isGlobalPauseActive
        isGlobalPauseActive = newPaused

        if newPaused {
            globalPauseWasTrackingEnabled = gazeEstimator.isTrackingEnabled
            gazeEstimator.setTrackingEnabled(false)
            stopListening()
            voiceInteractionService.stopListening()
        } else {
            if globalPauseWasTrackingEnabled {
                gazeEstimator.setTrackingEnabled(true)
            }
        }

        let statusMessage = newPaused ? "Tracking + Listening Paused" : "Tracking + Listening Resumed"
        let icon = newPaused ? "⏸" : "▶"

        try? "\(icon) Control+I: \(statusMessage)".appendLine(to: "/tmp/iris_live_debug.log")

        // Show visual feedback using DynamicUI
        showTrackingToggleNotification(enabled: !newPaused, icon: icon, message: statusMessage)
    }

    @MainActor
    private func showTrackingToggleNotification(enabled: Bool, icon: String, message: String) {
        let notificationSchema = DynamicUISchema(
            layout: UILayout(
                direction: .vertical,
                spacing: .sm,
                maxWidth: 300,
                padding: .md,
                alignment: .center
            ),
            theme: UITheme(
                accentColor: enabled ?
                    (SimulationConfig.isDevelopmentMode ? "#00D9FF" : "#A8D5BA") :
                    (SimulationConfig.isDevelopmentMode ? "#FF6B6B" : "#C5C5C5"),
                secondaryColor: enabled ?
                    (SimulationConfig.isDevelopmentMode ? "#7B61FF" : "#9BC5A3") :
                    (SimulationConfig.isDevelopmentMode ? "#FF4757" : "#B0B0B0"),
                background: .glass,
                mood: enabled ? .success : .neutral,
                icon: icon,
                title: message
            ),
            components: [
                .heading(HeadingComponent(
                    text: message,
                    level: 2,
                    icon: icon
                )),
                .paragraph(ParagraphComponent(
                    text: enabled ? "Eye tracking is now active" : "Eye tracking is now paused",
                    style: .muted
                ))
            ],
            screenshotConfig: nil,
            actions: nil
        )

        self.dynamicUISchema = notificationSchema
        self.isOverlayVisible = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.dynamicUISchema = nil
            self?.isOverlayVisible = false
        }
    }

    /// Called when VAD detects voice start.
    /// With continuous screen sharing, Gemini already has the screen context and audio stream.
    /// No overlay or screenshot trigger needed — Gemini handles turn detection server-side.
    public func handleVoiceStart() {
        if isGlobalPauseActive {
            return
        }
        suppressModelAudioUntilTurnComplete = false
        isProactiveCheckInProgress = false  // Cancel any proactive check suppression
        latencyTracker.reset()
        latencyTracker.markVoiceStart()

        debugVoiceStartTime = Date()
        logStatus("voice detected")

        if voiceAgentState == .modelSpeaking {
            print("⚡ BARGE-IN: User speaking during model response, stopping playback")
            latencyTracker.markInterrupt()
            audioPlaybackService.stop()
            voiceAgentState = .userSpeaking
        } else {
            voiceAgentState = .userSpeaking
        }

        if isLiveSessionActive {
            // Live API: continuous streaming already provides screen context at 1 FPS.
            // Sending a synchronous high-res screenshot here BLOCKS the voice start path
            // and adds 100-300ms of latency. The idle frames are sufficient context.
            // Just send the latest buffered frame if available (instant, no encoding).
            if let frame = continuousScreenCapture.latestFrame {
                geminiLiveClient.sendImageFrame(frame.jpegBase64)
            }
            return
        }

        // Fallback for when live session is not connected
        guard chatMessages.isEmpty && capturedScreenshot == nil && !isProcessing else {
            return
        }
        if let lastBlink = lastBlinkTime, Date().timeIntervalSince(lastBlink) < blinkCooldownPeriod {
            return
        }

        print("🔄 Live session not active, falling back to voice capture flow")
        let mouseLocation = NSEvent.mouseLocation
        guard let gazeScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            return
        }
        guard let screenshot = screenshotService.captureScreen(gazeScreen) else {
            print("❌ Failed to capture screenshot for voice trigger")
            return
        }
        lastBlinkTime = Date()
        capturedScreenshot = screenshot
        conversationManager.clearHistory()
        chatMessages.removeAll()
        startLegacyVoiceMode(screenshot: screenshot, focusedElement: nil)
    }

    /// Manual interrupt used by keyboard shortcut (Fn/Globe) to stop model speech immediately.
    @MainActor
    public func interruptModelSpeech() {
        guard voiceAgentState == .modelSpeaking || !liveGeminiResponse.isEmpty else {
            return
        }
        suppressModelAudioUntilTurnComplete = true
        audioPlaybackService.stop()
        voiceAgentState = .idle
        let msg = "🛑 Manual speech interrupt: suppressing model audio until turn completes"
        print(msg)
        try? msg.appendLine(to: "/tmp/iris_live_debug.log")
    }

    /// Periodically nudge Gemini to proactively offer a reply when user gaze is on a chat.
    private func maybeTriggerProactiveReplyCheck() {
        let now = Date()
        guard now.timeIntervalSince(lastProactiveCheckTime) >= proactiveCheckCooldown else { return }
        guard proactiveSuggestions.isEmpty else { return }
        guard voiceAgentState == .idle, !isProcessing else { return }
        guard !isProactiveCheckInProgress else { return }  // Don't overlap checks

        // Check frontmost app — log it for debugging
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = (frontApp?.localizedName ?? "unknown").lowercased()

        guard isChatLikeAppFrontmost() else {
            // Log once per cooldown so user can see why proactive isn't firing
            if frameSendCount % 15 == 0 {
                logStatus("idle on: \(appName)")
            }
            return
        }

        // Gather gaze context for smarter proactive prompts
        let gazePoint = MainActor.assumeIsolated { gazeEstimator.gazePoint }
        let detectedEl = MainActor.assumeIsolated { gazeEstimator.detectedElement }

        // Build element context string if user is fixating on something
        var gazeContext = "Gaze position: (\(Int(gazePoint.x)), \(Int(gazePoint.y)))."
        if let el = detectedEl {
            let typeStr = String(describing: el.type)
            gazeContext += " Looking at: \(el.label) (\(typeStr)) at (\(Int(el.bounds.midX)), \(Int(el.bounds.midY)))."
            // If user is looking at a text input, they might want to type — skip proactive reply
            let inputTypes = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
            if inputTypes.contains(typeStr) {
                if verboseLogsEnabled {
                    try? "💡 Proactive skipped: user gaze on text input (\(typeStr))".appendLine(to: "/tmp/iris_live_debug.log")
                }
                return
            }
        }

        lastProactiveCheckTime = now

        // Send the latest buffered frame — no synchronous capture needed.
        if let frame = continuousScreenCapture.latestFrame {
            geminiLiveClient.sendImageFrame(frame.jpegBase64)
        }

        // Mark proactive check in progress — suppresses all text/audio output
        // Only tool calls (propose_reply) will pass through
        isProactiveCheckInProgress = true
        logStatus("proactive check...")

        let proactivePrompt = """
        [SYSTEM INSTRUCTION — SILENT PROACTIVE CHECK]
        RULES: Do NOT speak. Do NOT generate audio. Do NOT generate text.
        ONLY action allowed: call the propose_reply tool.

        \(gazeContext)
        The orange dot on the screen shows where the user is looking.
        If they are looking at a message/conversation that could use a reply, call propose_reply with an appropriate response matching the tone and language of the conversation.
        If there is nothing to reply to, respond with absolutely nothing (empty turn).
        """
        geminiLiveClient.sendTextMessage(proactivePrompt)
        try? "💡 Proactive check sent — \(gazeContext)".appendLine(to: "/tmp/iris_live_debug.log")

        // Safety timeout: reset flag after 10s in case Gemini doesn't respond
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, self.isProactiveCheckInProgress else { return }
            self.isProactiveCheckInProgress = false
            self.logStatus("proactive timeout")
            try? "⚠️ Proactive check timed out after 10s".appendLine(to: "/tmp/iris_live_debug.log")
        }
    }

    private func isChatLikeAppFrontmost() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let name = (app.localizedName ?? "").lowercased()
        let bundleID = (app.bundleIdentifier ?? "").lowercased()
        let text = "\(name) \(bundleID)"

        let chatHints = [
            "slack", "messages", "imessage", "discord", "mail", "gmail",
            "telegram", "whatsapp", "signal", "teams", "messenger",
            "chatgpt", "claude", "gemini", "perplexity", "copilot",
            "safari", "chrome", "firefox", "arc", "brave", "edge", "opera",
            "linkedin", "twitter", "x.com", "instagram", "facebook"
        ]
        return chatHints.contains { text.contains($0) }
    }

    /// Called when VAD detects voice end.
    /// With continuous screen sharing, Gemini handles turn detection — this is a no-op for Live API.
    public func handleVoiceEnd() {
        debugVoiceEndTime = Date()
        logStatus("voice ended")

        if isLiveSessionActive {
            return
        }
    }

    /// Handles a complete turn from the Live API.
    /// In continuous mode, Gemini responds to voice queries about the shared screen.
    /// Responses are added to chat and the overlay is shown automatically.
    private static let conversationLogPath = "/tmp/iris_conversation.log"

    private func logConversationTurn(user: String, assistant: String) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let ts = df.string(from: Date())
        var entry = "\n[\(ts)]\n"
        if !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry += "USER: \(user)\n"
        }
        if !assistant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry += "IRIS: \(assistant)\n"
        }
        entry += "---\n"
        try? entry.appendLine(to: Self.conversationLogPath)
    }

    private func handleLiveTurnComplete() {
        let responseText = accumulatedLiveText
        let userTranscript = liveTranscription
        let hadWakeWord = wakeWordDetectedThisTurn
        accumulatedLiveText = ""
        liveGeminiResponse = ""
        liveTranscription = ""
        wakeWordDetectedThisTurn = false  // Reset for next turn

        // CRITICAL: Reset state to idle so the system is ready for the next turn.
        // Audio playback may still be draining, but the model is done generating.
        voiceAgentState = .idle
        suppressModelAudioUntilTurnComplete = false

        // Wake word gate: if required and not detected, silently discard the entire turn
        if wakeWordRequired && !hadWakeWord {
            let trimmedUser = userTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedUser.isEmpty {
                try? "🔇 Wake word not detected, discarding turn: \(trimmedUser.prefix(80))".appendLine(to: "/tmp/iris_live_debug.log")
            }
            return
        }

        let trimmedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResponse.isEmpty else {
            return
        }

        // Anti-loop: suppress "clarify" responses when user didn't actually speak
        let trimmedUser = userTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerResponse = trimmedResponse.lowercased()
        let clarifyPatterns = ["could you clarify", "can you clarify", "i didn't catch", "could you repeat",
                               "i'm not sure what you", "can you say that again", "sorry, i didn't understand",
                               "what did you mean", "i didn't quite get", "pardon"]
        let isClarifyResponse = clarifyPatterns.contains(where: { lowerResponse.contains($0) })
        if isClarifyResponse && trimmedUser.isEmpty {
            // Model is confused by noise — suppress to break the loop
            try? "🔁 Suppressed clarify-loop response (no user speech): \(trimmedResponse.prefix(80))".appendLine(to: "/tmp/iris_live_debug.log")
            return
        }

        // Anti-duplicate: skip if identical to last assistant message
        if let lastAssistant = chatMessages.last(where: { $0.role == .assistant }) {
            let lastText = lastAssistant.content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if lastText == lowerResponse {
                try? "🔁 Suppressed duplicate response: \(trimmedResponse.prefix(80))".appendLine(to: "/tmp/iris_live_debug.log")
                return
            }
        }

        // Log conversation to file with speaker labels
        logConversationTurn(user: userTranscript, assistant: responseText)

        // Add user's transcription as a user message (if available)
        if !trimmedUser.isEmpty {
            chatMessages.append(ChatMessage(role: .user, content: userTranscript, timestamp: Date()))
        }

        // Add assistant response to chat — this makes the overlay appear via shouldAcceptMouseEvents binding
        geminiResponse = responseText
        chatMessages.append(ChatMessage(role: .assistant, content: responseText, timestamp: Date()))
        isProcessing = false
        // No follow-up listener needed — audio keeps streaming, Gemini detects next turn
    }

    /// Receives audio buffers and forwards them to the encoder (always, for Live API)
    public func receiveAudioBufferForLive(_ buffer: AVAudioPCMBuffer) {
        if isGlobalPauseActive {
            return
        }
        guard isLiveSessionActive else { return }
        audioStreamEncoder.processBuffer(buffer)
    }

    /// Restored for protocol conformance - does nothing
    public func handleBlink(at point: CGPoint, focusedElement: DetectedElement?) {
        // No-op: blinking functionality removed
    }

    // Use an atomic or non-isolated flag for the audio thread to check without actor hop
    private var isListeningForBuffers = false

    private var bufferCount = 0
    public func receiveAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        if isGlobalPauseActive {
            return
        }
        // Always forward mic audio to Gemini Live — Gemini's own VAD handles turn-taking.
        // Never gate on audioPlaybackService.isPlaying; the user must always be heard.
        if isLiveSessionActive {
            audioStreamEncoder.processBuffer(buffer)
        }

        // Forward to voice interaction service for legacy blink flow
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

    public func startListening() {
        // Wrapper for AIProvider protocol conformance
        if isGlobalPauseActive {
            return
        }
        self.handleVoiceStart()
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

            // Clear proactive suggestions state
            self.proactiveSuggestions = []
            self.isAnalyzingScreenshot = false
            self.voiceAgentState = .idle
            self.detectedContext = ""

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

    /// Starts the inactivity timer - DISABLED (user controls dismissal via scroll up)
    private func startInactivityTimer() {
        // Inactivity auto-close disabled - user dismisses via scroll up gesture or voice command
        // Keeping the method for potential future use
        print("⏱️ Inactivity timer disabled (user controls dismissal via scroll up)")
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

    // MARK: - Proactive Intent Analysis

    /// Analyzes the screenshot immediately to suggest likely user intents
    private func analyzeScreenshotForIntent(screenshot: NSImage, focusedElement: DetectedElement?) async {
        print("🔮 analyzeScreenshotForIntent: Starting proactive analysis...")

        await MainActor.run {
            self.isAnalyzingScreenshot = true
            self.voiceAgentState = .analyzing
            self.proactiveSuggestions = []
            self.detectedContext = ""
        }

        // Convert screenshot to base64
        guard let base64Image = screenshotService.imageToBase64(screenshot) else {
            print("❌ analyzeScreenshotForIntent: Failed to convert screenshot")
            await MainActor.run {
                self.isAnalyzingScreenshot = false
                self.voiceAgentState = .idle
            }
            // Fall back to voice-only mode
            startLegacyVoiceMode(screenshot: screenshot, focusedElement: focusedElement)
            return
        }

        // Build the proactive intent prompt
        let systemPrompt = proactiveIntentPromptBuilder.buildSystemPrompt()
        let userPrompt = proactiveIntentPromptBuilder.buildUserPrompt()
        let fullPrompt = systemPrompt + "\n\n" + userPrompt

        // Convert base64 to Data
        guard let imageData = Data(base64Encoded: base64Image) else {
            print("❌ analyzeScreenshotForIntent: Failed to decode image data")
            await MainActor.run {
                self.isAnalyzingScreenshot = false
                self.voiceAgentState = .idle
            }
            startLegacyVoiceMode(screenshot: screenshot, focusedElement: focusedElement)
            return
        }

        // Create message for Gemini
        let message = ModelContent(
            role: "user",
            parts: [
                ModelContent.Part.text(fullPrompt),
                ModelContent.Part.data(mimetype: "image/jpeg", imageData)
            ]
        )

        do {
            print("🌐 analyzeScreenshotForIntent: Sending to Gemini...")

            // Send non-streaming request for faster response
            let responseText = try await geminiClient.sendRequest(history: [message])

            print("✅ analyzeScreenshotForIntent: Got response")

            // Parse and enrich the response with skill info
            if let parsed = proactiveIntentPromptBuilder.parseAndEnrich(responseText) {
                await MainActor.run {
                    self.proactiveSuggestions = parsed.suggestions
                    self.detectedContext = parsed.context
                    self.isAnalyzingScreenshot = false
                    self.voiceAgentState = .idle

                    // Log enriched suggestions with skill info
                    for suggestion in parsed.suggestions {
                        if let skillId = suggestion.matchedSkill {
                            print("🎯 Suggestion '\(suggestion.label)' matched to skill: \(skillId) (canAct: \(suggestion.canAct))")
                        } else {
                            print("🔮 Suggestion '\(suggestion.label)' (no skill match)")
                        }
                    }

                    // Check for auto-execute (single high-confidence suggestion that can act)
                    if parsed.suggestions.count == 1,
                       let suggestion = parsed.suggestions.first,
                       suggestion.shouldAutoExecute {
                        print("🚀 Auto-executing high-confidence agentic suggestion: \(suggestion.label)")
                        Task {
                            await self.executeProactiveSuggestion(suggestion)
                        }
                    }
                }
            } else {
                print("⚠️ analyzeScreenshotForIntent: Failed to parse response")
                await MainActor.run {
                    self.isAnalyzingScreenshot = false
                    self.voiceAgentState = .idle
                }
            }

            // Start listening for voice commands in parallel (for suggestion selection or custom request)
            startListeningForSuggestionSelection()

        } catch {
            print("❌ analyzeScreenshotForIntent: Error - \(error)")
            await MainActor.run {
                self.isAnalyzingScreenshot = false
                self.voiceAgentState = .idle
            }
            // Fall back to voice-only mode on error
            startLegacyVoiceMode(screenshot: screenshot, focusedElement: focusedElement)
        }
    }

    /// Executes a selected proactive suggestion
    public func executeProactiveSuggestion(_ suggestion: ProactiveSuggestion) async {
        print("🎯 Executing proactive suggestion: \(suggestion.label) (intent: \(suggestion.intent))")

        // Handle direct browser actions (like search) without Gemini
        if suggestion.isDirectBrowserAction {
            await handleDirectBrowserAction(suggestion)
            return
        }

        // Check if this suggestion has a matched skill that can act directly
        if let skillId = suggestion.matchedSkill,
           let skill = skillRegistry.skill(for: skillId),
           suggestion.canAct {
            print("🎯 Executing via skill: \(skill.name)")

            // For web-search, handle directly without Gemini
            if skillId == "web-search" {
                await handleDirectBrowserAction(suggestion)
                return
            }

            // Store suggestion for later execution after Gemini responds
            await MainActor.run {
                self.currentMatchedSkill = skill
            }
        }

        guard let screenshot = await MainActor.run(body: { self.capturedScreenshot }) else {
            print("❌ No screenshot available for execution")
            return
        }

        await MainActor.run {
            // Clear suggestions since we're executing one
            self.proactiveSuggestions = []

            // Set the current intent for UI layout
            self.currentIntent = suggestion.icoiIntent
            print("📌 Set currentIntent to: \(suggestion.icoiIntent.rawValue)")

            // Add user message showing the action
            self.chatMessages.append(ChatMessage(role: .user, content: suggestion.label, timestamp: Date()))
        }

        // Get the execution prompt for this suggestion
        let prompt = suggestion.executionPrompt

        // Send to Gemini with the full context
        // After Gemini responds, we'll execute the skill if applicable
        await sendToGeminiWithSkillExecution(
            screenshot: screenshot,
            prompt: prompt,
            focusedElement: currentFocusedElement,
            suggestion: suggestion
        )
    }

    /// Sends to Gemini and then executes skill if applicable
    private func sendToGeminiWithSkillExecution(
        screenshot: NSImage,
        prompt: String,
        focusedElement: DetectedElement?,
        suggestion: ProactiveSuggestion
    ) async {
        // First, send to Gemini normally
        await sendToGemini(screenshot: screenshot, prompt: prompt, focusedElement: focusedElement)

        // After Gemini responds, check if we should execute a skill
        if suggestion.canAct, suggestion.matchedSkill != nil {
            // Get the Gemini response that was just generated
            let geminiResponse = await MainActor.run { self.geminiResponse }

            // Execute the skill with the response
            await handleSkillExecution(suggestion: suggestion, geminiResponse: geminiResponse)
        }
    }

    /// Handles direct browser actions like search (no Gemini call needed)
    private func handleDirectBrowserAction(_ suggestion: ProactiveSuggestion) async {
        print("🌐 Handling direct browser action: \(suggestion.intent)")

        await MainActor.run {
            // Clear UI state
            self.proactiveSuggestions = []
            self.isOverlayVisible = false
            self.capturedScreenshot = nil
            self.chatMessages.removeAll()
        }

        // Extract search query from the label or context
        let searchQuery = suggestion.label
            .replacingOccurrences(of: "Search for ", with: "")
            .replacingOccurrences(of: "Search ", with: "")
            .replacingOccurrences(of: "Google ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔍 Executing Google search via ActionExecutor: \(searchQuery)")

        // Use ActionExecutor for the search
        actionExecutor.googleSearch(searchQuery)
    }

    // MARK: - Skill Execution

    /// Handles skill execution after Gemini responds
    /// This is the core of Phase 4 - wiring skills to actually execute actions
    private func handleSkillExecution(
        suggestion: ProactiveSuggestion,
        geminiResponse: String
    ) async {
        print("🎯 handleSkillExecution called for suggestion: \(suggestion.label)")

        guard let skillId = suggestion.matchedSkill,
              let skill = skillRegistry.skill(for: skillId),
              suggestion.canAct else {
            print("⚠️ Skill execution skipped - no skill match or can't act")
            return
        }

        print("🎯 Executing skill: \(skill.name) (id: \(skillId))")

        await MainActor.run {
            self.currentMatchedSkill = skill
            self.isExecutingSkill = true
            self.executionProgress = "Planning actions for \(skill.name)..."
        }

        // Create screen context from current state
        let context = ScreenContext.from(context: detectedContext)

        do {
            // Generate action plan
            let plan = try await actionPlanner.planActions(
                skill: skill,
                context: context,
                userRequest: suggestion.label,
                geminiResponse: geminiResponse
            )

            print("📋 Action plan generated with \(plan.steps.count) steps")

            // Check if confirmation is needed
            let shouldAutoExecute = skill.canAutoExecute && suggestion.confidence >= skill.autoExecuteThreshold
            let needsConfirmation = plan.requiresConfirmation && !shouldAutoExecute

            if needsConfirmation {
                print("⚠️ Showing execution confirmation for plan")
                await MainActor.run {
                    self.pendingActionPlan = plan
                    self.showExecutionConfirmation = true
                    self.isExecutingSkill = false
                }
            } else {
                print("🚀 Auto-executing plan (confidence: \(suggestion.confidence), threshold: \(skill.autoExecuteThreshold))")
                await executePlan(plan)
            }
        } catch {
            print("❌ Failed to plan actions: \(error)")
            await MainActor.run {
                self.isExecutingSkill = false
                self.executionProgress = "Failed to plan: \(error.localizedDescription)"
            }
        }
    }

    /// Executes an action plan
    private func executePlan(_ plan: ActionPlan) async {
        await MainActor.run {
            self.isExecutingSkill = true
            self.executionProgress = "Executing \(plan.description)..."
        }

        do {
            // Set up progress callback
            actionPlanner.onProgress = { [weak self] progress in
                Task { @MainActor in
                    self?.executionProgress = progress
                }
            }

            let result = try await actionPlanner.executePlan(plan)

            await MainActor.run {
                self.lastExecutionResult = result
                self.isExecutingSkill = false
                self.pendingActionPlan = nil
                self.showExecutionConfirmation = false
            }

            await handleExecutionResult(result)
        } catch {
            print("❌ Plan execution failed: \(error)")
            await MainActor.run {
                self.isExecutingSkill = false
                self.executionProgress = "Execution failed: \(error.localizedDescription)"
            }
        }
    }

    /// Handles the result of an execution
    private func handleExecutionResult(_ result: ExecutionResult) async {
        if result.overallSuccess {
            print("✅ Execution completed successfully in \(String(format: "%.2f", result.duration))s")

            // Show success notification
            do {
                try await actionPlanner.quickNotify(
                    "Done! (\(result.successCount) actions completed)",
                    title: "IRIS"
                )
            } catch {
                print("⚠️ Failed to show notification: \(error)")
            }

            // Auto-close overlay after successful execution
            await MainActor.run {
                self.executionProgress = "✅ Completed"
            }

            // Delay then close
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            await MainActor.run {
                self.resetConversationState()
            }
        } else {
            print("❌ Execution failed: \(result.failureCount) actions failed")

            let errorMessage = result.results.first { !$0.success }?.error ?? "Unknown error"

            await MainActor.run {
                self.executionProgress = "❌ Failed: \(errorMessage)"
            }

            // Show error notification
            do {
                try await actionPlanner.quickNotify(
                    "Failed: \(errorMessage)",
                    title: "IRIS Error"
                )
            } catch {
                print("⚠️ Failed to show error notification: \(error)")
            }
        }
    }

    /// Confirms and executes the pending action plan
    public func confirmExecution() {
        guard let plan = pendingActionPlan else {
            print("⚠️ No pending plan to confirm")
            return
        }

        print("✅ User confirmed execution")

        Task {
            await executePlan(plan)
        }
    }

    /// Cancels the pending action plan
    public func cancelExecution() {
        print("❌ User cancelled execution")

        pendingActionPlan = nil
        showExecutionConfirmation = false
        isExecutingSkill = false
        executionProgress = ""
    }

    /// Parses voice input for execution commands
    private func parseExecutionCommand(_ input: String) -> ExecutionVoiceCommand? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Execute commands
        let executeCommands = ["do it", "execute", "yes", "go", "run it", "make it so", "confirm", "ok", "okay"]
        if executeCommands.contains(where: { normalized.contains($0) }) {
            return .execute
        }

        // Preview commands
        let previewCommands = ["show me", "preview", "what will happen", "details"]
        if previewCommands.contains(where: { normalized.contains($0) }) {
            return .preview
        }

        // Cancel commands
        let cancelCommands = ["stop", "cancel", "nevermind", "never mind", "no", "abort", "undo"]
        if cancelCommands.contains(where: { normalized.contains($0) }) {
            return .cancel
        }

        return nil
    }

    /// Handles a voice command for execution
    private func handleExecutionVoiceCommand(_ command: ExecutionVoiceCommand) {
        switch command {
        case .execute:
            confirmExecution()

        case .preview:
            // Already showing confirmation UI with preview
            print("📋 Preview requested - confirmation UI already visible")

        case .cancel:
            cancelExecution()
        }
    }

    /// Voice commands for skill execution
    enum ExecutionVoiceCommand {
        case execute
        case preview
        case cancel
    }

    /// Starts listening for suggestion selection (voice commands like "one", "two", etc.)
    private func startListeningForSuggestionSelection() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.isGlobalPauseActive else { return }

            guard self.capturedScreenshot != nil else {
                print("⚠️ No screenshot, not starting suggestion listener")
                return
            }

            guard !self.isListening else {
                print("⚠️ Already listening")
                return
            }

            print("🎧 Listening for suggestion selection or custom request...")

            let timeout: TimeInterval = 10.0  // Longer timeout for proactive mode

            self.isListening = true
            self.isListeningForBuffers = true
            self.bufferCount = 0

            // Set timeout countdown
            self.remainingTimeout = timeout
            self.timeoutStartTime = Date()
            self.startCountdownTimer(totalTimeout: timeout)

            self.voiceInteractionService.startListening(timeout: timeout, useExternalAudio: true, onSpeechDetected: { [weak self] in
                DispatchQueue.main.async {
                    self?.countdownTimer?.invalidate()
                    self?.countdownTimer = nil
                    self?.remainingTimeout = nil
                }
            }, onPartialResult: { [weak self] partialText in
                DispatchQueue.main.async {
                    self?.liveTranscription = partialText
                }
            }) { [weak self] voiceInput in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isListening = false
                    self.liveTranscription = ""
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                    self.remainingTimeout = nil
                }

                // Check for stop command
                if self.isStopCommand(voiceInput) {
                    print("🛑 Stop command detected")
                    DispatchQueue.main.async {
                        self.resetConversationState()
                    }
                    return
                }

                // Check for execution commands (when confirmation is pending)
                if self.showExecutionConfirmation, let command = self.parseExecutionCommand(voiceInput) {
                    print("🎯 Execution command detected: \(command)")
                    DispatchQueue.main.async {
                        self.handleExecutionVoiceCommand(command)
                    }
                    return
                }

                // Check if user is selecting a suggestion number
                if let suggestionNumber = self.parseSuggestionSelection(voiceInput) {
                    let suggestions = self.proactiveSuggestions
                    if suggestionNumber >= 1 && suggestionNumber <= suggestions.count {
                        let selectedSuggestion = suggestions[suggestionNumber - 1]
                        print("🔢 User selected suggestion \(suggestionNumber): \(selectedSuggestion.label)")
                        Task {
                            await self.executeProactiveSuggestion(selectedSuggestion)
                        }
                        return
                    } else {
                        print("⚠️ Invalid suggestion number: \(suggestionNumber), max: \(suggestions.count)")
                    }
                }

                // Not a suggestion selection - treat as custom request
                guard !voiceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    print("⚠️ Empty voice input - keeping suggestions visible")
                    // Re-start listening
                    self.startListeningForSuggestionSelection()
                    return
                }

                print("🎤 Custom request: \(voiceInput)")

                // Clear suggestions and process as regular request
                DispatchQueue.main.async {
                    self.proactiveSuggestions = []
                }

                Task { @MainActor in
                    // Classify intent for the custom request
                    let intentClassification = await intentClassificationService.classifyIntent(input: voiceInput)
                    self.currentIntent = intentClassification.intent

                    // Add user message
                    self.chatMessages.append(ChatMessage(role: .user, content: voiceInput, timestamp: Date()))

                    // Send to Gemini
                    if let screenshot = self.capturedScreenshot {
                        await self.sendToGemini(screenshot: screenshot, prompt: voiceInput, focusedElement: self.currentFocusedElement)
                    }
                }
            }
        }
    }

    /// Parses voice input to detect suggestion selection (e.g., "one", "1", "first")
    private func parseSuggestionSelection(_ input: String) -> Int? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Number words
        let numberWords: [String: Int] = [
            "one": 1, "1": 1, "first": 1, "won": 1,
            "two": 2, "2": 2, "second": 2, "to": 2, "too": 2,
            "three": 3, "3": 3, "third": 3
        ]

        // Check for exact match
        if let number = numberWords[normalized] {
            return number
        }

        // Check if input starts with a number word
        for (word, number) in numberWords {
            if normalized.hasPrefix(word + " ") || normalized.hasPrefix(word + ".") {
                return number
            }
        }

        // Check for patterns like "option one", "select two", "number three"
        let patterns = ["option", "select", "number", "choice", "pick"]
        for pattern in patterns {
            for (word, number) in numberWords {
                if normalized.contains("\(pattern) \(word)") {
                    return number
                }
            }
        }

        return nil
    }

    /// Falls back to legacy voice-first mode when proactive analysis fails
    private func startLegacyVoiceMode(screenshot: NSImage, focusedElement: DetectedElement?) {
        print("🎤 Falling back to legacy voice mode...")

        let timeoutDuration: TimeInterval = 5.0

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.remainingTimeout = timeoutDuration
            self.timeoutStartTime = Date()
            self.startCountdownTimer(totalTimeout: timeoutDuration)

            self.isListeningForBuffers = true
            self.bufferCount = 0
        }

        voiceInteractionService.startListening(timeout: timeoutDuration, useExternalAudio: true, onSpeechDetected: { [weak self] in
            DispatchQueue.main.async {
                self?.isListening = true
                self?.countdownTimer?.invalidate()
                self?.countdownTimer = nil
                self?.remainingTimeout = nil
            }
        }, onPartialResult: { [weak self] partialText in
            DispatchQueue.main.async {
                self?.liveTranscription = partialText
            }
        }) { [weak self] prompt in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.timeoutStartTime = nil
                self.remainingTimeout = nil
            }

            if self.isStopCommand(prompt) {
                DispatchQueue.main.async {
                    self.resetConversationState()
                }
                return
            }

            guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            Task { @MainActor in
                let intentClassification = await intentClassificationService.classifyIntent(input: prompt)
                self.currentIntent = intentClassification.intent

                // Check for duplicate before adding user message
                if !self.chatMessages.contains(where: { $0.role == .user && $0.content == prompt }) {
                    self.chatMessages.append(ChatMessage(role: .user, content: prompt, timestamp: Date()))
                    print("✅ Added user message to chat (startLegacyVoiceMode): '\(prompt.prefix(50))...'")
                } else {
                    print("⚠️ Duplicate user message detected, skipping: '\(prompt.prefix(50))...'")
                }

                await self.sendToGemini(screenshot: screenshot, prompt: prompt, focusedElement: focusedElement)
            }
        }
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

        // Choose request mode based on whether we need to parse structured data
        print("🌐 About to send Gemini API request...")
        do {
            // Clear previous live response
            await MainActor.run {
                self.liveGeminiResponse = ""
            }

            let responseText: String

            if useDynamicUIValue {
                // Dynamic UI mode: Use non-streaming to get full response first, then parse
                print("🌐 Using non-streaming request for Dynamic UI (need to parse JSON first)...")
                responseText = try await geminiClient.sendRequest(history: conversationManager.getHistory())

                print("🌐 Received complete response from Gemini!")
                print("✅ Got response text: \(responseText.prefix(100))...")

                // Parse immediately to extract text and UI schema
                let parsed = dynamicUIResponseParser.parse(response: responseText)

                // Update UI schema first (so it's ready when we display)
                await MainActor.run {
                    if let schema = parsed.schema {
                        self.dynamicUISchema = schema
                        print("✅ Dynamic UI schema parsed with \(schema.components.count) components")
                    } else {
                        self.dynamicUISchema = nil
                        print("⚠️ No UI schema found in response")
                    }
                    self.markActivity()
                }

                // Now display only the human-readable text (not the raw JSON)
                let displayText = parsed.text.isEmpty ? responseText : parsed.text
                await MainActor.run {
                    self.liveGeminiResponse = displayText
                }
            } else {
                // Standard mode: Use streaming for real-time display
                print("🌐 Calling geminiClient.sendStreamingRequest...")
                let (text, functionCalls) = try await geminiClient.sendStreamingRequest(history: conversationManager.getHistory()) { [weak self] partialText in
                    // Update live Gemini response in real-time
                    Task { @MainActor in
                        self?.liveGeminiResponse = partialText
                        self?.markActivity()  // Mark activity when Gemini is responding
                    }
                }
                responseText = text

                print("🌐 Received complete response from Gemini!")
                print("✅ Got response text: \(responseText.prefix(100))...")

                if !functionCalls.isEmpty {
                    print("🛠️ Received \(functionCalls.count) function calls")
                    await handleFunctionCalls(functionCalls, originalResponseText: responseText)
                    return // Stop duplicate processing, handleFunctionCalls will trigger follow-up
                }
            }

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
                // Parse dynamic UI response (schema already parsed above, this handles chat message update)
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

            let (text, functionCalls) = try await geminiClient.sendStreamingRequest(history: conversationManager.getHistory()) { [weak self] partialText in
                // Update live Gemini response in real-time
                Task { @MainActor in
                    self?.liveGeminiResponse = partialText
                    self?.markActivity()  // Mark activity when Gemini is responding
                }
            }
            let responseText = text

            if !functionCalls.isEmpty {
                 await handleFunctionCalls(functionCalls, originalResponseText: responseText)
                 return
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
        - CRITICAL: BE CONCISE AND DIRECT - Keep responses brief (2-4 sentences max) while maintaining helpful context
        - Provide the essential answer first, then add ONE brief supporting detail if truly necessary
        - Use markdown formatting for better readability: **bold** for emphasis, `code` for technical terms, - lists for multiple items
        - For factual questions (dates, numbers, laws, statistics): VERIFY accuracy before responding - if uncertain, acknowledge it
        - ALWAYS respond from the USER's perspective (right side)
        - When analyzing messages, analyze what was sent TO the USER (from left side)
        - When suggesting replies, suggest what the USER should send (from right side)
        - Focus on the USER's personal situation and context
        - In chats: RIGHT = USER, LEFT = OTHER PERSON (this is absolute and never changes)
        - Example: If asked "what should I reply?", give ONE concise suggestion with brief reasoning
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

    /// Handles responses from the dynamic UI system - updates chat messages with display text
    /// Note: Schema is already parsed in sendToGemini before this is called
    private func handleDynamicUIResponse(responseText: String) async {
        print("🎨 handleDynamicUIResponse called")

        // Parse to extract just the display text (schema already set in sendToGemini)
        let parsed = dynamicUIResponseParser.parse(response: responseText)
        let displayText = parsed.text.isEmpty ? responseText : parsed.text

        print("🎨 Display text length: \(displayText.count)")

        await MainActor.run {
            self.geminiResponse = displayText
            self.isProcessing = false

            // Replace the assistant loading bubble with actual response
            if let lastIndex = self.chatMessages.lastIndex(where: { $0.role == .assistant && $0.content == "..." }) {
                self.chatMessages[lastIndex] = ChatMessage(role: .assistant, content: displayText, timestamp: Date())
            } else {
                // Add new message
                self.chatMessages.append(ChatMessage(role: .assistant, content: displayText, timestamp: Date()))
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

        // Generate and play audio response for Germany users only
        if LocaleDetector.isGermany() {
            print("🇩🇪 Germany locale detected - generating audio response")
            Task {
                do {
                    let audioData = try await geminiAudioClient.generateAudioResponse(text: responseText)
                    try geminiAudioClient.playAudio(audioData)
                    print("🔊 Audio response played successfully")
                } catch {
                    print("⚠️ Failed to generate/play audio response: \(error.localizedDescription)")
                }
            }
        } else {
            print("🌍 Non-Germany locale - skipping audio response")
        }

        // Auto-close timer removed - user explicitly dismissed via scroll up or voice command
        // Keeping user in control of when to close the overlay
        print("⏰ Auto-close timer disabled (user controls dismissal via scroll up or voice command)")

        startListeningForFollowup()
    }

    private func startListeningForFollowup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.isGlobalPauseActive else { return }

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
                    print("⚠️ No follow-up question detected after 5s timeout - keeping overlay open (user dismisses via scroll up)")
                    // Don't auto-close - user can dismiss via scroll up gesture or voice command
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

    // MARK: - Agentic Tool Handling

    private func handleFunctionCalls(_ functionCalls: [FunctionCall], originalResponseText: String) async {
        print("🤖 Handling \(functionCalls.count) function calls")

        // 1. Add the Assistant's Tool Call message to history
        var assistantParts: [ModelContent.Part] = []
        if !originalResponseText.isEmpty {
            assistantParts.append(.text(originalResponseText))
        }
        for call in functionCalls {
            assistantParts.append(.functionCall(call))
        }

        let assistantMessage = ModelContent(role: "model", parts: assistantParts)
        conversationManager.addMessage(assistantMessage)

        // 2. Execute each tool and collect responses
        var responseParts: [ModelContent.Part] = []

        for call in functionCalls {
            print("🔧 Executing function: \(call.name)")
            let result = await executeToolCall(call)

            // Create FunctionResponse part
            let responsePart = ModelContent.Part.functionResponse(
                FunctionResponse(name: call.name, response: ["result": .string(result)])
            )
            responseParts.append(responsePart)
            print("✅ Tool result: \(result.prefix(100))...")
        }

        let toolResponseMessage = ModelContent(role: "user", parts: responseParts) // Using 'user' role for tool response in Swift SDK
        conversationManager.addMessage(toolResponseMessage)

        // 4. Send back to Gemini (Loop)
        print("🔄 Sending tool outputs back to Gemini...")

        await MainActor.run {
            self.liveGeminiResponse = "Thinking..." // Show activity
            self.isProcessing = true
        }

        do {
            // Recursive call logic - reuse sendStreamingRequest logic
            let (responseText, nextFunctionCalls) = try await geminiClient.sendStreamingRequest(history: conversationManager.getHistory()) { [weak self] partialText in
                 Task { @MainActor in
                     self?.liveGeminiResponse = partialText
                     self?.markActivity()
                 }
            }

            await MainActor.run { self.liveGeminiResponse = "" }

            if !nextFunctionCalls.isEmpty {
                // Recursive loop
                await handleFunctionCalls(nextFunctionCalls, originalResponseText: responseText)
            } else {
                // Final response
                let finalAssistantMessage = ModelContent(role: "model", parts: [.text(responseText)])
                conversationManager.addMessage(finalAssistantMessage)

                // Process final response normally
                // Treat as General intent since we are deep in agentic loop
                let intent = IntentClassification(intent: .general, confidence: 1.0)
                await handleNormalResponse(responseText: responseText, intentClassification: intent)
            }

        } catch {
            print("❌ Error in Agentic Loop: \(error)")
            await MainActor.run {
                self.geminiResponse = "Error executing action: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }

    private func executeToolCall(_ call: FunctionCall) async -> String {
        let args = call.args
        let name = call.name

        do {
            switch name {
            case "click":
                guard case .number(let x) = args["x"], case .number(let y) = args["y"] else { return "Error: Missing x,y arguments" }
                // Convert coordinates if needed?
                // Gemini sees screenshot size. We assume it matches screen coords for now (Retina?)
                // ScreenshotService usually captures at screen resolution.
                let action = Action(type: .click, parameters: ["x": String(x), "y": String(y)], description: "Click (\(x), \(y))")
                return try await ActionExecutor.shared.execute(action).output ?? "Clicked"

            case "type_text":
                guard case .string(let text) = args["text"] else { return "Error: Missing text argument" }
                // Trim trailing newlines to prevent accidental submission
                let cleanText = text.trimmingCharacters(in: .newlines)
                let action = Action.typeText(cleanText)
                return try await ActionExecutor.shared.execute(action).output ?? "Typed"

            case "scroll":
                let direction: String
                if case .string(let dir) = args["direction"] {
                    direction = dir
                } else {
                    direction = "down"
                }
                let amount: Int
                if case .number(let amt) = args["amount"] {
                    amount = Int(amt)
                } else {
                    amount = 5
                }
                let action = Action.scroll(direction: direction, amount: amount)
                return try await ActionExecutor.shared.execute(action).output ?? "Scrolled"

            case "open_app":
                guard case .string(let appName) = args["app_name"] else { return "Error: Missing app_name" }
                // Try Activate first
                let action = Action(type: .activateApp, parameters: ["app": appName], description: "Open \(appName)")
                return try await ActionExecutor.shared.execute(action).output ?? "Opened \(appName)"

            case "google_search":
                guard case .string(let query) = args["query"] else { return "Error: Missing query" }
                let action = Action.openUrl("https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
                return try await ActionExecutor.shared.execute(action).output ?? "Searched"

            case "run_terminal_command":
                guard case .string(let cmd) = args["command"] else { return "Error: Missing command" }
                // Security check?
                let action = Action.runCommand(cmd, requiresConfirmation: false) // Agentic mode implies permission?
                return try await ActionExecutor.shared.execute(action).output ?? "Command executed"

            case "read_file":
                guard case .string(let path) = args["path"] else { return "Error: Missing path" }
                let action = Action(type: .readFile, parameters: ["path": path], description: "Read \(path)")
                return try await ActionExecutor.shared.execute(action).output ?? "Read file"

            case "write_file":
                guard case .string(let path) = args["path"], case .string(let content) = args["content"] else { return "Error: Missing path or content" }
                 let action = Action(type: .writeFile, parameters: ["path": path, "content": content], description: "Write \(path)")
                return try await ActionExecutor.shared.execute(action).output ?? "Wrote file"

            default:
                return "Error: Unknown tool \(name)"
            }
        } catch {
            return "Error executing \(name): \(error.localizedDescription)"
        }
    }

    private func executeLiveTool(name: String, args: [String: Any]) async -> String {
        let logMsg = "🚀 executeLiveTool: '\(name)' args=\(args)"
        print(logMsg)
        try? logMsg.appendLine(to: "/tmp/iris_live_debug.log")

        await MainActor.run {
            self.currentTool = (name, args)
        }
        defer {
            Task { @MainActor in
                self.currentTool = nil
            }
        }

        do {
            switch name {
            case "click_at":
                // Auto-redirect to tars_action — Gemini is bad at guessing coordinates
                let x = args["x"] as? Double ?? 0
                let y = args["y"] as? Double ?? 0
                try? "🔄 click_at(\(Int(x)),\(Int(y))) redirected to tars_action".appendLine(to: "/tmp/iris_live_debug.log")
                let tarsInstruction = "click at the element near coordinates (\(Int(x)), \(Int(y)))"
                return await executeLiveTool(name: "tars_action", args: ["instruction": tarsInstruction])

            case "type_text":
                guard let text = args["text"] as? String else { return "Error: Missing text" }
                let cleanText = text.trimmingCharacters(in: .newlines)
                // Use CGEvent keyboard via clipboard paste (Cmd+V) — no Automation permission needed
                let pasteboard = NSPasteboard.general
                let oldContent = pasteboard.string(forType: .string)
                pasteboard.clearContents()
                pasteboard.setString(cleanText, forType: .string)

                let source = CGEventSource(stateID: .hidSystemState)
                let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 'v'
                let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                vDown?.flags = .maskCommand
                vUp?.flags = .maskCommand
                vDown?.post(tap: .cghidEventTap)
                try await Task.sleep(nanoseconds: 30_000_000)
                vUp?.post(tap: .cghidEventTap)
                try await Task.sleep(nanoseconds: 80_000_000)

                // Restore previous clipboard
                if let old = oldContent {
                    pasteboard.clearContents()
                    pasteboard.setString(old, forType: .string)
                }
                let result = "Typed \(cleanText.count) characters"
                try? "✅ type_text('\(cleanText.prefix(50))') -> \(result)".appendLine(to: "/tmp/iris_live_debug.log")
                return result

            case "press_key":
                guard let key = args["key"] as? String else { return "Error: Missing key" }
                // Use CGEvent directly — no Automation permission needed
                let specialKeys: [String: CGKeyCode] = [
                    "return": 36, "enter": 36, "tab": 48, "space": 49,
                    "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
                    "up": 126, "down": 125, "left": 123, "right": 124
                ]
                let normalizedKey = key.lowercased().trimmingCharacters(in: .whitespaces)
                let source = CGEventSource(stateID: .hidSystemState)
                if let keyCode = specialKeys[normalizedKey] {
                    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                    keyDown?.post(tap: .cghidEventTap)
                    try await Task.sleep(nanoseconds: 30_000_000)
                    keyUp?.post(tap: .cghidEventTap)
                } else if normalizedKey.count == 1, let scalar = normalizedKey.unicodeScalars.first {
                    // Single character — map common chars to key codes
                    let charKeyMap: [Character: CGKeyCode] = [
                        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
                        "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
                        "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9,
                        "w": 13, "x": 7, "y": 16, "z": 6
                    ]
                    if let kc = charKeyMap[Character(scalar)] {
                        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: kc, keyDown: true)
                        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: kc, keyDown: false)
                        keyDown?.post(tap: .cghidEventTap)
                        try await Task.sleep(nanoseconds: 30_000_000)
                        keyUp?.post(tap: .cghidEventTap)
                    }
                }
                return "Pressed \(key)"

            case "run_terminal_command":
                guard let command = args["command"] as? String else { return "Error: Missing command" }
                let action = Action(type: .runCommand, parameters: ["command": command], description: "Run: \(command)")
                return try await ActionExecutor.shared.execute(action).output ?? "Ran command"

            case "open_app":
                guard let appName = args["name"] as? String else { return "Error: Missing name" }
                // Use NSWorkspace — no AppleScript/Automation permission needed
                let workspace = NSWorkspace.shared
                let apps = workspace.runningApplications
                // Try to activate a running app first
                if let running = apps.first(where: { ($0.localizedName ?? "").lowercased() == appName.lowercased() }) {
                    running.activate()
                    return "Activated \(appName)"
                }
                // Try to open by name via Launch Services
                if let appUrl = workspace.urlForApplication(withBundleIdentifier: appName) {
                    try await workspace.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration())
                    return "Opened \(appName)"
                }
                // Try common app paths
                let paths = [
                    "/Applications/\(appName).app",
                    "/System/Applications/\(appName).app",
                    "/System/Applications/Utilities/\(appName).app"
                ]
                for path in paths {
                    let url = URL(fileURLWithPath: path)
                    if FileManager.default.fileExists(atPath: path) {
                        try await workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                        return "Opened \(appName)"
                    }
                }
                return "Error: Could not find app '\(appName)'"

            case "scroll":
                let direction = args["direction"] as? String ?? "down"
                let amount = (args["amount"] as? Double).map { Int($0) } ?? 5
                // Use CGEvent directly — no Automation permission needed
                let scrollY: Int32 = direction.lowercased() == "up" ? Int32(amount) : Int32(-amount)
                let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: scrollY, wheel2: 0, wheel3: 0)
                event?.post(tap: .cghidEventTap)
                return "Scrolled \(direction) by \(amount)"

            case "propose_reply":
                guard let reply = args["reply"] as? String else { return "Error: Missing reply" }
                let explanation = args["explanation"] as? String ?? ""

                let cleanReply = reply.trimmingCharacters(in: .newlines)

                // Step 1: Find and focus the text input field via Accessibility API
                if let frontApp = NSWorkspace.shared.frontmostApplication {
                    let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
                    // Try to find the focused element first
                    var focusedValue: AnyObject?
                    AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
                    var focusedRole: String?
                    if let focused = focusedValue {
                        var roleValue: AnyObject?
                        AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXRoleAttribute as CFString, &roleValue)
                        focusedRole = roleValue as? String
                    }
                    // If focused element is not a text field, use TARS to find the message input
                    let textRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
                    if focusedRole == nil || !textRoles.contains(focusedRole!) {
                        try? "📍 propose_reply: no text field focused, asking TARS to find input".appendLine(to: "/tmp/iris_live_debug.log")
                        let tarsClickResult = await executeLiveTool(name: "tars_action", args: ["instruction": "click the message input field or text box where you type a message"])
                        try? "📍 propose_reply: TARS focus result: \(tarsClickResult)".appendLine(to: "/tmp/iris_live_debug.log")
                        try await Task.sleep(nanoseconds: 150_000_000) // wait for focus after TARS click
                    }
                }

                // Step 2: Paste the reply via Cmd+V
                let pasteboard = NSPasteboard.general
                let oldContent = pasteboard.string(forType: .string)
                pasteboard.clearContents()
                pasteboard.setString(cleanReply, forType: .string)

                let source = CGEventSource(stateID: .hidSystemState)
                let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
                let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                vDown?.flags = .maskCommand
                vUp?.flags = .maskCommand
                vDown?.post(tap: .cghidEventTap)
                try await Task.sleep(nanoseconds: 30_000_000)
                vUp?.post(tap: .cghidEventTap)
                try await Task.sleep(nanoseconds: 80_000_000)

                // Restore previous clipboard
                if let old = oldContent {
                    pasteboard.clearContents()
                    pasteboard.setString(old, forType: .string)
                }

                // Show UI notification — persists until user dismisses or next voice turn
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let suggestion = ProactiveSuggestion(
                        id: 1,
                        intent: "reply",
                        label: reply,
                        confidence: 0.95,
                        autoExecute: true,
                        matchedSkill: "message-composer",
                        canAct: true,
                        actionPreview: "Typed: \(reply)"
                    )
                    self.proactiveSuggestions = [suggestion]
                    self.detectedContext = explanation
                }

                let result = "Reply typed into the chat input field: \(cleanReply.prefix(50)). The input field is focused. NOW SAY 'Send it?' and WAIT for user response. If user says 'send'/'yes'/'oui'/'go'/'ok' → call press_key('return') to send the message. If user says 'no'/'cancel'/'annule' → call press_key('Control+a') then press_key('delete') to clear it."
                try? "✅ propose_reply -> \(result)".appendLine(to: "/tmp/iris_live_debug.log")
                Task { @MainActor [weak self] in
                    self?.logStatus("reply typed — say 'send' or 'cancel'")
                }
                return result

            case "tars_action":
                guard let instruction = args["instruction"] as? String else {
                    return "Error: Missing instruction"
                }
                let textToType = args["text"] as? String
                try? "🤖 tars_action: \(instruction) text=\(textToType ?? "nil")".appendLine(to: "/tmp/iris_live_debug.log")

                // Step 1: Capture current screenshot as base64 JPEG
                let screenshotBase64: String
                if let screen = NSScreen.main {
                    let screenRect = screen.frame
                    if let cgImage = CGWindowListCreateImage(screenRect, .optionOnScreenOnly, kCGNullWindowID, .nominalResolution) {
                        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                            screenshotBase64 = jpegData.base64EncodedString()
                        } else {
                            return "Error: Failed to encode screenshot as JPEG"
                        }
                    } else {
                        return "Error: Failed to capture screenshot"
                    }
                } else {
                    return "Error: No main screen"
                }

                // Step 2: Get screen dimensions
                let screenWidth = Int(NSScreen.main?.frame.width ?? 1920)
                let screenHeight = Int(NSScreen.main?.frame.height ?? 1080)

                // Step 3: Call TARS server
                let tarsURL = URL(string: "http://192.168.1.147:8100/action")!
                var request = URLRequest(url: tarsURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 30

                let payload: [String: Any] = [
                    "screenshot_base64": screenshotBase64,
                    "instruction": instruction,
                    "screen_width": screenWidth,
                    "screen_height": screenHeight
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let body = String(data: data, encoding: .utf8) ?? "no body"
                    try? "❌ TARS server error: \(statusCode) \(body)".appendLine(to: "/tmp/iris_live_debug.log")
                    return "Error: TARS server returned status \(statusCode)"
                }

                guard let tarsResult = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return "Error: Failed to parse TARS response"
                }

                let actionType = tarsResult["action_type"] as? String ?? "unknown"
                let thought = tarsResult["thought"] as? String ?? ""
                let latencyMs = tarsResult["latency_ms"] as? Double ?? 0
                try? "🤖 TARS result: action=\(actionType) thought=\(thought) latency=\(latencyMs)ms".appendLine(to: "/tmp/iris_live_debug.log")

                // Step 4: Execute the action returned by TARS
                switch actionType {
                case "click":
                    guard let x = tarsResult["x"] as? Double, let y = tarsResult["y"] as? Double else {
                        return "TARS found no coordinates for: \(instruction)"
                    }
                    let point = CGPoint(x: x, y: y)
                    let src = CGEventSource(stateID: .hidSystemState)
                    let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
                    let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
                    down?.post(tap: .cghidEventTap)
                    try await Task.sleep(nanoseconds: 30_000_000)
                    up?.post(tap: .cghidEventTap)

                    // If text was provided, type it after clicking
                    if let text = textToType, !text.isEmpty {
                        try await Task.sleep(nanoseconds: 150_000_000) // wait for focus
                        let pasteboard = NSPasteboard.general
                        let oldClip = pasteboard.string(forType: .string)
                        pasteboard.clearContents()
                        pasteboard.setString(text, forType: .string)
                        let source = CGEventSource(stateID: .hidSystemState)
                        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
                        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                        vDown?.flags = .maskCommand
                        vUp?.flags = .maskCommand
                        vDown?.post(tap: .cghidEventTap)
                        try await Task.sleep(nanoseconds: 30_000_000)
                        vUp?.post(tap: .cghidEventTap)
                        if let old = oldClip {
                            try await Task.sleep(nanoseconds: 80_000_000)
                            pasteboard.clearContents()
                            pasteboard.setString(old, forType: .string)
                        }
                        let typeResult = "Clicked at (\(Int(x)), \(Int(y))) and typed '\(text.prefix(50))' — \(thought)"
                        try? "✅ tars_action click+type -> \(typeResult)".appendLine(to: "/tmp/iris_live_debug.log")
                        return typeResult
                    }

                    let clickResult = "Clicked at (\(Int(x)), \(Int(y))) — \(thought)"
                    try? "✅ tars_action click -> \(clickResult)".appendLine(to: "/tmp/iris_live_debug.log")
                    return clickResult

                case "type":
                    guard let text = tarsResult["text"] as? String else {
                        return "TARS returned type action but no text"
                    }
                    // If coordinates provided, click there first
                    if let x = tarsResult["x"] as? Double, let y = tarsResult["y"] as? Double {
                        let point = CGPoint(x: x, y: y)
                        let src = CGEventSource(stateID: .hidSystemState)
                        let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
                        let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
                        down?.post(tap: .cghidEventTap)
                        try await Task.sleep(nanoseconds: 30_000_000)
                        up?.post(tap: .cghidEventTap)
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                    // Type via clipboard paste
                    let pasteboard = NSPasteboard.general
                    let oldContent = pasteboard.string(forType: .string)
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    let source = CGEventSource(stateID: .hidSystemState)
                    let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
                    let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                    vDown?.flags = .maskCommand
                    vUp?.flags = .maskCommand
                    vDown?.post(tap: .cghidEventTap)
                    try await Task.sleep(nanoseconds: 30_000_000)
                    vUp?.post(tap: .cghidEventTap)
                    if let old = oldContent {
                        try await Task.sleep(nanoseconds: 80_000_000)
                        pasteboard.clearContents()
                        pasteboard.setString(old, forType: .string)
                    }
                    let typeResult = "Typed '\(text.prefix(50))' — \(thought)"
                    try? "✅ tars_action type -> \(typeResult)".appendLine(to: "/tmp/iris_live_debug.log")
                    return typeResult

                case "scroll":
                    let direction = tarsResult["direction"] as? String ?? "down"
                    let scrollAmount: Int32 = direction == "up" ? 5 : -5
                    let src = CGEventSource(stateID: .hidSystemState)
                    let scrollEvent = CGEvent(scrollWheelEvent2Source: src, units: .line, wheelCount: 1, wheel1: scrollAmount, wheel2: 0, wheel3: 0)
                    scrollEvent?.post(tap: .cghidEventTap)
                    let scrollResult = "Scrolled \(direction) — \(thought)"
                    try? "✅ tars_action scroll -> \(scrollResult)".appendLine(to: "/tmp/iris_live_debug.log")
                    return scrollResult

                case "hotkey":
                    let key = tarsResult["key"] as? String ?? ""
                    // Delegate to existing press_key logic
                    let hotkeyResult = await executeLiveTool(name: "press_key", args: ["key": key])
                    try? "✅ tars_action hotkey -> \(hotkeyResult)".appendLine(to: "/tmp/iris_live_debug.log")
                    return "Pressed \(key) — \(thought)"

                case "drag":
                    if let startX = tarsResult["start_x"] as? Double, let startY = tarsResult["start_y"] as? Double,
                       let endX = tarsResult["end_x"] as? Double, let endY = tarsResult["end_y"] as? Double {
                        let src = CGEventSource(stateID: .hidSystemState)
                        let startPoint = CGPoint(x: startX, y: startY)
                        let endPoint = CGPoint(x: endX, y: endY)
                        let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left)
                        down?.post(tap: .cghidEventTap)
                        try await Task.sleep(nanoseconds: 50_000_000)
                        let drag = CGEvent(mouseEventSource: src, mouseType: .leftMouseDragged, mouseCursorPosition: endPoint, mouseButton: .left)
                        drag?.post(tap: .cghidEventTap)
                        try await Task.sleep(nanoseconds: 50_000_000)
                        let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left)
                        up?.post(tap: .cghidEventTap)
                        let dragResult = "Dragged from (\(Int(startX)),\(Int(startY))) to (\(Int(endX)),\(Int(endY))) — \(thought)"
                        try? "✅ tars_action drag -> \(dragResult)".appendLine(to: "/tmp/iris_live_debug.log")
                        return dragResult
                    }
                    return "TARS returned drag action but missing coordinates"

                default:
                    let tarsMsg = "TARS action '\(actionType)' not yet supported. Thought: \(thought)"
                    try? "⚠️ tars_action unsupported: \(tarsMsg)".appendLine(to: "/tmp/iris_live_debug.log")
                    return tarsMsg
                }

            case "learn_and_execute":
                guard let task = args["task"] as? String else { return "Error: Missing task" }
                let context = args["context"] as? String ?? ""
                try? "🧠 learn_and_execute: task='\(task)' context='\(context)'".appendLine(to: "/tmp/iris_live_debug.log")
                let result = await GeminiCLIService.shared.learnAndExecute(task: task, context: context)
                try? "✅ learn_and_execute result: \(result.prefix(200))".appendLine(to: "/tmp/iris_live_debug.log")
                return result

            default:
                let unknownMsg = "❌ Unknown tool: \(name)"
                try? unknownMsg.appendLine(to: "/tmp/iris_live_debug.log")
                return "Error: Unknown tool \(name)"
            }
        } catch {
            let errMsg = "❌ Tool '\(name)' FAILED: \(error.localizedDescription)"
            print(errMsg)
            try? errMsg.appendLine(to: "/tmp/iris_live_debug.log")
            return "Error executing \(name): \(error.localizedDescription)"
        }
    }
}
