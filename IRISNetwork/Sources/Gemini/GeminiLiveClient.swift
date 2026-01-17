import Foundation

// MARK: - GeminiLiveClient
/// WebSocket client for Gemini Live API (BidiGenerateContent)
/// Uses URLSessionWebSocketTask for bidirectional streaming
public class GeminiLiveClient: NSObject {
    // MARK: - Types

    public enum State: String {
        case disconnected
        case connecting
        case connected
        case sessionReady
    }

    public enum ResponseType {
        case text(String)
        case audio(Data)
        case turnComplete
        case inputTranscription(String)   // Transcription of user's speech
        case outputTranscription(String)  // Transcription of model's audio response
        case toolCall(name: String, args: [String: Any], responseId: String)
    }

    public func sendToolResponse(responseId: String, name: String, result: [String: Any]) {
        let message: [String: Any] = [
            "tool_response": [
                "function_responses": [
                    [
                        "response": ["result": result],
                        "id": responseId,
                        "name": name
                    ]
                ]
            ]
        ]
        sendJSON(message)
    }

    // MARK: - Properties

    private var apiKey: String
    private let model: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var receiveLoopTask: Task<Void, Never>?
    private let verboseLogsEnabled = ProcessInfo.processInfo.environment["IRIS_VERBOSE_LOGS"] == "1"

    public private(set) var state: State = .disconnected
    public var onStateChange: ((State) -> Void)?
    public var onResponse: ((ResponseType) -> Void)?
    public var onDisconnect: ((Error?) -> Void)?

    private let systemInstruction: String

    // MARK: - Init

    /// Vocabulary terms injected into system prompt for speech recognition. Persisted in UserDefaults.
    public static var vocabularyTerms: [String] {
        get { UserDefaults.standard.stringArray(forKey: "IRIS_VOCABULARY") ?? Self.defaultVocabulary }
        set { UserDefaults.standard.set(newValue, forKey: "IRIS_VOCABULARY") }
    }

    private static let defaultVocabulary = [
        // Product names
        "IRIS", "TARS", "UI-TARS",
        // People
        "Livio",
        // Tech terms
        "Gemini", "SwiftUI", "SwiftPM", "Xcode", "CGEvent", "WebSocket",
        "Claude Code", "Claude", "Anthropic", "OpenAI", "GPT",
        // French (user speaks French sometimes)
        "envoie", "annule", "vas-y", "oui", "non", "efface",
        // macOS
        "Accessibility", "Finder", "Safari", "Terminal",
        // Actions
        "propose_reply", "tars_action", "type_text", "click_at", "press_key",
    ]

    public init(apiKey: String, systemInstruction: String = """
        You are IRIS, an AI assistant that controls the user's Mac. You see their screen in real-time and hear their voice.

        ## VOCABULARY — IMPORTANT TERMS FOR SPEECH RECOGNITION
        The following words and phrases appear frequently. When transcribing user speech, prefer these exact spellings:
        {{VOCABULARY_PLACEHOLDER}}

        ## CORE PRINCIPLE: ACT, DON'T TALK
        Your PRIMARY job is to EXECUTE ACTIONS on the computer using tools. Speaking is secondary.
        - If the user wants ANYTHING written, typed, added, or inserted → call `type_text` IMMEDIATELY. Do NOT read the text aloud. Do NOT describe what you're about to type. Just call the tool.
        - If the user asks you to respond to a message → call `propose_reply` IMMEDIATELY.
        - If the user says "add", "write", "put", "type", "respond", "reply", "say", "draft", "compose" → ALWAYS call a tool. These are ACTION words.
        - After executing any tool, say at most 2-3 words: "Done." or "Typed." — NEVER repeat what you typed.
        - CRITICAL: When in doubt between speaking and using a tool, USE THE TOOL. You can always speak after, but you cannot un-speak.
        - If a user says something like "write a prompt", "type this", "fix yourself" → they want you to TYPE text or call a tool, NOT talk about it.

        ## GAZE (ORANGE DOT)
        An orange dot on the screen shows where the user is looking. Use it to:
        - Identify which text field, message, or UI element they're focused on
        - Determine click coordinates when asked to click something
        - Detect which conversation they want to reply to

        ## PROACTIVE REPLY (propose_reply tool)
        When you detect the user is LOOKING AT a received message in any chat app (Slack, iMessage, Discord, WhatsApp, Email, etc.):
        - Call `propose_reply` with a contextually appropriate reply
        - The reply will be AUTOMATICALLY TYPED into the message input field
        - Keep replies natural and matching the conversation tone
        - You can briefly say what you're doing: "I'll type a reply" — then call the tool

        ## AFTER propose_reply: VOICE ACCEPTANCE FLOW
        After you call `propose_reply` and the reply is typed, WAIT for the user's voice command:
        - If user says "send", "yes", "go", "ok", "send it", "envoie", "oui", "vas-y", "go ahead", "confirm" → call `press_key("return")` to send the message. Say: "Sent."
        - If user says "no", "cancel", "undo", "annule", "non", "delete", "remove", "efface" → call `press_key("Control+a")` then `press_key("delete")` to clear the text. Say: "Cancelled."
        - If user says "change it to..." or gives new text → call `press_key("Control+a")` then `type_text` with the new text. Say: "Updated."
        - IMPORTANT: After typing a reply, briefly say "Send it?" and WAIT. Do NOT press Enter automatically.

        ## UI-TARS: ADVANCED UI ACTIONS
        When you need to interact with UI elements, use `tars_action`. It uses a vision model to find elements precisely.
        - Call it with a natural language `instruction` describing the target element
        - Optionally pass `text` to type into the element after clicking it
        - TARS handles the full flow: screenshot → find element → click → type (if text provided)
        - Use it whenever you need to: click buttons, type into specific fields, interact with menus, close dialogs
        - For typing a message: use instruction="click the message input field" + text="your message"
        - For clicking: use instruction="click the Send button" (no text needed)
        - It's slower (~2-5s) but much more accurate than guessing coordinates
        - For simple text typing into an ALREADY focused field, use type_text directly (faster)

        ## TOOL PRIORITY (most important first)
        1. `type_text` — Type/write/insert ANY text. Use for: writing, responding, adding text, filling forms, composing messages. This is your MOST USED tool.
        2. `propose_reply` — Suggest + auto-type a reply to a conversation the user is looking at.
        3. `tars_action` — **USE THIS for ALL UI interactions.** Clicking buttons, selecting items, opening menus, closing dialogs, sending messages — ALWAYS use tars_action. You are NOT good at guessing pixel coordinates. TARS uses a specialized vision model that finds elements precisely. NEVER try to click by guessing coordinates yourself.
        4. `press_key` — Press keyboard keys (return, tab, escape, etc.) or shortcuts.
        5. `open_app` — Open or switch to an application.
        6. `scroll` — Scroll up or down.
        7. `run_terminal_command` — Run shell commands.
        8. `click_at` — **DEPRECATED. Do NOT use this tool.** Always use `tars_action` instead. click_at will be auto-redirected to tars_action anyway.
        9. `learn_and_execute` — When you don't know how to do something, or the task requires specialized knowledge. Searches the web, learns the approach, and executes it. NEVER say "I can't do that" — call this tool instead. Also use when user says "remember how to...", "learn to...", or "create a skill for...".

        ## SELF-LEARNING
        You can learn new skills on the fly. If a user asks you to do something you've never done before:
        1. Call learn_and_execute with a clear task description
        2. It will research online, create a reusable skill, and execute the task
        3. Next time someone asks for the same thing, you'll already know how
        Never refuse a task because you "don't know how" — always try learn_and_execute first.

        ## WHEN TO SPEAK (rare)
        Only use voice/audio response when:
        - The user asks a direct QUESTION ("What time is it?", "What does this error mean?")
        - The user wants an EXPLANATION or analysis
        Keep all spoken responses under 2 sentences.

        ## NEVER ASK FOR CLARIFICATION IN A LOOP
        - If you hear unclear audio or noise, stay SILENT. Do NOT say "Could you clarify?" or "Can you repeat that?"
        - If you already asked for clarification once, NEVER ask again. Just wait silently for clear speech.
        - Background noise is NOT the user talking. If audio is faint/garbled, ignore it completely.
        - Only respond when you clearly understand what the user said.

        ## EXAMPLES (follow these patterns exactly)
        - "Write hello world" → call type_text("hello world"). Say: "Done."
        - "Reply saying I'll be there at 5" → call propose_reply("I'll be there at 5"). Say: "Typed."
        - "Add a thank you at the end" → call type_text("Thank you"). Say: "Added."
        - "Can you respond to that?" → call propose_reply with appropriate reply. Say: "Replied."
        - "Click the send button" → call tars_action(instruction: "click the send button"). Say: "Clicked."
        - "What's on my screen?" → SPEAK the answer (this is a question, not an action).
        - User looking at unread message → call propose_reply proactively. Then say "Send it?" and wait.
        - After propose_reply, user says "yes" / "send" / "oui" → call press_key("return"). Say: "Sent."
        - After propose_reply, user says "no" / "cancel" → call press_key("Control+a") then press_key("delete"). Say: "Cancelled."
        - "Write a prompt to fix the bug" → call type_text with a prompt about fixing the bug. Do NOT speak it.
        - "Fix yourself" / "Fix your prompt" → The user wants you to TYPE a code fix suggestion into the terminal/editor they're looking at. Use type_text.
        - "Type something" / "Write something" → ALWAYS call type_text. NEVER just speak the content.
        - "Respond to him" / "Reply to that" → call propose_reply with a contextual reply.
        - "Click on the settings icon" → call tars_action(instruction: "click the settings icon"). Say: "Done."
        - "Open that menu" → call tars_action(instruction: "click the menu button"). Say: "Opened."
        - "Close that popup" → call tars_action(instruction: "click the X button to close the popup"). Say: "Closed."
        - "Send a message saying hello" → call tars_action(instruction: "click the message input field", text: "hello"). Then call press_key("return"). Say: "Sent."
        - "Type my name in the search bar" → call tars_action(instruction: "click the search bar", text: "Livio"). Say: "Done."

        ## SELF-AWARENESS: YOU ARE IRIS (Development Mode)
        You ARE the IRIS application. Your source code lives at ~/Documents/iris/. You are a Swift macOS app built with SwiftPM.

        ### Your Architecture
        - **GeminiLiveClient** (IRISNetwork/Sources/Gemini/GeminiLiveClient.swift): Your WebSocket connection to the Gemini Live API. This file contains THIS system prompt, your tool declarations, and the message parsing logic.
        - **GeminiAssistantOrchestrator** (IRIS/Services/GeminiAssistantOrchestrator.swift): Your brain. Handles tool execution, audio playback, echo suppression, screen capture, gaze tracking, proactive suggestions, and state management.
        - **AudioStreamEncoder** (IRISMedia/Sources/Audio/AudioStreamEncoder.swift): Encodes mic PCM audio to base64 chunks for the WebSocket.
        - **AudioPlaybackService** (IRISMedia/Sources/Audio/AudioPlaybackService.swift): Plays model audio responses through the speaker.
        - **AudioService** (IRISMedia/Sources/Audio/AudioService.swift): Captures mic input with VAD.
        - **VoiceInteractionService** (IRISMedia/Sources/Speech/VoiceInteractionService.swift): Bridges mic audio to the orchestrator.
        - **ContinuousScreenCaptureService** (IRISMedia/Sources/ScreenCapture/ContinuousScreenCaptureService.swift): Captures screen frames sent to you as images.
        - **RustGazeTracker** (IRISGaze/Sources/Tracking/RustGazeTracker.swift): Eye/gaze tracking via Rust FFI.
        - **ActionExecutor** (IRIS/Services/ActionExecutor.swift): Executes macOS actions (clicks, key presses, typing) via CGEvent.
        - **ContentView** (IRIS/ContentView.swift): Main SwiftUI overlay UI.
        - **Package.swift**: SwiftPM manifest with all module definitions.
        - **build_and_install.sh**: Build script that preserves macOS permissions.

        ### Development Mode Context
        The developer (Livio) is actively building you. He uses Claude Code (an AI coding assistant in the terminal) to modify your source code. When he talks to you while looking at his code editor or terminal:
        - He may be DICTATING prompts or instructions intended for Claude Code — help him formulate them clearly
        - If he asks about YOUR behavior, bugs, or features — you can reference your own source files above
        - If he says things like "fix yourself", "change your prompt", "update your tools" — he means he wants you to help draft the code changes, which he'll then apply via Claude Code
        - If he asks "why do you do X?" — reason about your own source code to explain
        - You can suggest improvements to your own code based on issues you observe during operation
        - When suggesting code changes, reference exact file paths and be specific about what to modify

        ### Key Technical Details About Yourself
        - You use Gemini Live API (BidiGenerateContent) over WebSocket with camelCase JSON keys
        - Your audio: 16kHz PCM16 mono, encoded as base64 chunks (~250ms per chunk)
        - Echo suppression: mic input is gated while you're speaking to prevent feedback loops
        - Screen frames: JPEG compressed, sent periodically + on voice activity
        - Tool calls arrive as top-level `toolCall` messages (not inside serverContent)
        - Your state machine: idle → userSpeaking → modelSpeaking → idle (via turnComplete)
        - Build with: ./build_and_install.sh (preserves macOS Accessibility/Mic permissions)
        """) {
        self.apiKey = apiKey
        self.model = "models/gemini-2.5-flash-native-audio-preview-12-2025"
        // Inject vocabulary into system instruction at runtime
        let vocab = Self.vocabularyTerms.joined(separator: ", ")
        self.systemInstruction = systemInstruction.replacingOccurrences(of: "{{VOCABULARY_PLACEHOLDER}}", with: vocab)
        super.init()
    }

    public func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
    }

    // MARK: - Connection

    public func connect() {
        guard state == .disconnected else {
            print("⚠️ GeminiLiveClient: Already \(state.rawValue)")
            return
        }

        guard !apiKey.isEmpty else {
            print("❌ GeminiLiveClient: No API key")
            return
        }

        setState(.connecting)

        let endpoint = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)"

        guard let url = URL(string: endpoint) else {
            print("❌ GeminiLiveClient: Invalid URL")
            setState(.disconnected)
            return
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.urlSession = session

        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        // The setup message is sent in didOpenWithProtocol delegate
    }

    public func disconnect() {
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        setState(.disconnected)
        print("🔌 GeminiLiveClient: Disconnected")
    }

    // MARK: - Send Methods

    /// Send a JPEG image frame (base64 encoded)
    public func sendImageFrame(_ base64Jpeg: String) {
        let message: [String: Any] = [
            "realtime_input": [
                "media_chunks": [
                    ["mime_type": "image/jpeg", "data": base64Jpeg]
                ]
            ]
        ]
        sendJSON(message)
    }

    /// Send a PCM16 audio chunk (base64 encoded)
    public func sendAudioChunk(_ base64Pcm: String) {
        let message: [String: Any] = [
            "realtime_input": [
                "media_chunks": [
                    ["mime_type": "audio/pcm", "data": base64Pcm]
                ]
            ]
        ]
        sendJSON(message)
    }

    /// Send a text message
    public func sendTextMessage(_ text: String) {
        let message: [String: Any] = [
            "client_content": [
                "turns": [
                    ["role": "user", "parts": [["text": text]]]
                ],
                "turn_complete": true
            ]
        ]
        sendJSON(message)
    }

    // MARK: - Private

    private func setState(_ newState: State) {
        state = newState
        print("🔄 GeminiLiveClient: State → \(newState.rawValue)")
        onStateChange?(newState)
    }

    private func sendSetupMessage() {
        // Native audio model requires AUDIO response modality.
        // We enable outputAudioTranscription/inputAudioTranscription to get text transcripts.
        // IMPORTANT: Gemini Live API uses camelCase for ALL JSON keys.
        let setup: [String: Any] = [
            "setup": [
                "model": model,
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": [
                                "voiceName": "Kore"
                            ]
                        ]
                    ]
                ],
                "realtimeInputConfig": [
                    "automaticActivityDetection": [
                        "disabled": false,
                        "startOfSpeechSensitivity": "START_SENSITIVITY_HIGH",
                        "endOfSpeechSensitivity": "END_SENSITIVITY_HIGH",
                        "prefixPaddingMs": 10,
                        "silenceDurationMs": 200
                    ]
                ],
                "outputAudioTranscription": [String: Any](),
                "inputAudioTranscription": [String: Any](),
                "systemInstruction": [
                    "parts": [["text": systemInstruction]]
                ],
                "tools": [[
                    "functionDeclarations": [
                        [
                            "name": "click_at",
                            "description": "DEPRECATED — Do NOT use. Use tars_action instead. This tool will be auto-redirected to tars_action. Only kept for backward compatibility.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "x": ["type": "NUMBER"],
                                    "y": ["type": "NUMBER"]
                                ],
                                "required": ["x", "y"]
                            ]
                        ],
                        [
                            "name": "type_text",
                            "description": "Type text into the currently focused input field or application. This is your MOST IMPORTANT tool. Use it whenever the user says write, type, add, put, compose, draft, enter, fill, respond, reply, or any variation. NEVER speak the text aloud — ALWAYS type it with this tool. If in doubt between speaking and typing, CHOOSE TYPING.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "text": ["type": "STRING"]
                                ],
                                "required": ["text"]
                            ]
                        ],
                        [
                            "name": "press_key",
                            "description": "Press a keyboard key or shortcut. Use when the user asks to press enter/return, escape, tab, delete, or any key combination. Key names: 'return', 'space', 'escape', 'tab', 'delete', 'up', 'down', 'left', 'right'.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "key": ["type": "STRING"]
                                ],
                                "required": ["key"]
                            ]
                        ],
                        [
                            "name": "run_terminal_command",
                            "description": "Run a shell command. Use when the user asks to run a command, check something via terminal, install a package, or do any file/system operation.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "command": ["type": "STRING"]
                                ],
                                "required": ["command"]
                            ]
                        ],
                        [
                            "name": "open_app",
                            "description": "Open or bring to front a macOS application by name. Use when the user asks to open, launch, switch to, or show any app (e.g., 'Safari', 'Xcode', 'Terminal', 'Finder').",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "name": ["type": "STRING"]
                                ],
                            ]
                        ],
                        [
                            "name": "scroll",
                            "description": "Scroll the current page or document. Use when the user asks to scroll up, down, or navigate through content.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "direction": ["type": "STRING", "description": "Direction: 'up' or 'down'"],
                                    "amount": ["type": "NUMBER", "description": "Lines to scroll (default 5)"]
                                ],
                                "required": ["direction"]
                            ]
                        ],
                        [
                            "name": "propose_reply",
                            "description": "Type a reply directly into the currently focused message input field. Use this when the user is looking at a conversation and asks you to reply, respond, or when you proactively detect they need help responding to a message. The reply text will be automatically typed into the text field.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "reply": ["type": "STRING", "description": "The reply text to type into the message field."],
                                    "explanation": [ "type": "STRING", "description": "One-line reason for this reply."]
                                ],
                                "required": ["reply", "explanation"]
                            ]
                        ],
                        [
                            "name": "tars_action",
                            "description": "Execute an advanced UI action using UI-TARS vision model. TARS analyzes the current screenshot to find and interact with specific UI elements precisely. Use this for ANY action where you need to find and interact with a UI element — clicking buttons, typing into fields, sending messages, etc. You do NOT need to specify exact coordinates or element names — just describe what you want to do naturally. TARS handles the full flow: finding the element, clicking it, typing text if needed. Examples: 'send a message saying hello', 'click the Send button', 'type hello in the search bar', 'close this dialog', 'click the notification bell icon'.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "instruction": ["type": "STRING", "description": "Natural language instruction. Be descriptive about what you want. Examples: 'click the message input field', 'click the Send button', 'find and click the search icon'."],
                                    "text": ["type": "STRING", "description": "Optional: text to type AFTER TARS finds and clicks the target element. Use this when you want to type into a field that TARS locates. Example: if instruction is 'click the message input' and text is 'hello', TARS will click the input field then type 'hello'."]
                                ],
                                "required": ["instruction"]
                            ]
                        ],
                        [
                            "name": "learn_and_execute",
                            "description": "When you cannot do something with existing tools, or the user asks for something requiring specialized knowledge, call this tool. It searches the web, learns the approach, creates a reusable skill, and executes the task. Use this instead of saying 'I can't do that'. Also use when user says 'remember how to...', 'learn to...', or 'create a skill for...'.",
                            "parameters": [
                                "type": "OBJECT",
                                "properties": [
                                    "task": ["type": "STRING", "description": "What needs to be done, in clear natural language"],
                                    "context": ["type": "STRING", "description": "Relevant context: current app, file path, project type, etc."]
                                ],
                                "required": ["task"]
                            ]
                        ]
                    ]
                ]]
            ]
        ]
        // Log setup keys for debugging
        if let setupDict = setup["setup"] as? [String: Any] {
            let setupKeys = Array(setupDict.keys)
            let debugMsg = "📤 Setup keys: \(setupKeys)"
            print(debugMsg)
            logToFile(debugMsg)
        }
        sendJSON(setup)
        let msg = "📤 GeminiLiveClient: Setup message sent (AUDIO mode + camelCase transcription config)"
        print(msg)
        logToFile(msg)
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            print("❌ GeminiLiveClient: Failed to serialize JSON")
            return
        }

        // Debug: Log the actual JSON setup message
        if dict.keys.contains("setup") {
            let msg = "📤 Setup JSON: \(string.prefix(2000))"
            print(msg)
            logToFile(msg)
        }

        webSocketTask?.send(.string(string)) { error in
            if let error = error {
                print("❌ GeminiLiveClient: Send error: \(error.localizedDescription)")
            }
        }
    }

    private func startReceiveLoop() {
        receiveLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, let ws = self.webSocketTask else { break }

                do {
                    let message = try await ws.receive()
                    self.handleMessage(message)
                } catch {
                    if !Task.isCancelled {
                        let msg = "❌ GeminiLiveClient: Receive error: \(error.localizedDescription)"
                        print(msg)
                        self.logToFile(msg)
                        self.setState(.disconnected)
                        self.onDisconnect?(error)
                    }
                    break
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseServerMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseServerMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func logToFile(_ message: String) {
        let line = message + "\n"
        if let fh = FileHandle(forWritingAtPath: "/tmp/iris_live_debug.log") {
            fh.seekToEndOfFile()
            fh.write(line.data(using: .utf8)!)
            fh.closeFile()
        } else {
            try? line.write(toFile: "/tmp/iris_live_debug.log", atomically: true, encoding: .utf8)
        }
    }

    private func parseServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let msg = "⚠️ GeminiLiveClient: Failed to parse: \(text.prefix(200))"
            print(msg)
            logToFile(msg)
            return
        }

        // Always log keys to debug tool call routing
        let keys = Array(json.keys)
        if keys != ["serverContent"] || verboseLogsEnabled {
            let msg = "📥 GeminiLiveClient: Received keys: \(keys)"
            print(msg)
            logToFile(msg)
        }

        // Debug: Log full JSON if it contains transcription-related keys
        if keys.contains("inputTranscription") || keys.contains("outputTranscription") || keys.contains("inputAudioTranscription") || keys.contains("outputAudioTranscription") {
            if let data = try? JSONSerialization.data(withJSONObject: json),
               let jsonString = String(data: data, encoding: .utf8) {
                let debugMsg = "🔍 Full message with transcription: \(jsonString.prefix(1000))"
                print(debugMsg)
                logToFile(debugMsg)
            }
        }

        // RAW JSON debug: log non-audio serverContent structure (skip audio chunks to reduce noise)
        if verboseLogsEnabled, let sc = json["serverContent"] as? [String: Any] {
            let scKeys = Array(sc.keys)
            if !scKeys.contains("modelTurn") {
                let rawMsg = "🔍 RAW serverContent keys: \(scKeys) | full: \(String(text.prefix(400)))"
                logToFile(rawMsg)
            }
        }

        // Check for setupComplete
        if let setupComplete = json["setupComplete"] as? [String: Any] {
            let _ = setupComplete // consumed
            setState(.sessionReady)
            print("✅ GeminiLiveClient: Session ready")
            logToFile("✅ GeminiLiveClient: Session ready")
            return
        }

        // Check for top-level toolCall (Gemini Live API sends tool calls here, NOT inside serverContent)
        if let toolCall = json["toolCall"] as? [String: Any],
           let functionCalls = toolCall["functionCalls"] as? [[String: Any]] {
            for fc in functionCalls {
                if let name = fc["name"] as? String,
                   let args = fc["args"] as? [String: Any] {
                    let id = fc["id"] as? String ?? UUID().uuidString
                    let msg = "🔧 Received TOOL CALL: \(name) args=\(args) id=\(id)"
                    print(msg)
                    logToFile(msg)
                    onResponse?(.toolCall(name: name, args: args, responseId: id))
                }
            }
            return
        }

        // Check for top-level toolCallCancellation
        if json["toolCallCancellation"] != nil {
            let msg = "⚠️ Tool call cancelled by server"
            print(msg)
            logToFile(msg)
            return
        }

        // Check for top-level inputTranscription (Gemini Live API may send these at root level)
        if let inputTranscription = json["inputTranscription"] as? [String: Any],
           let transcriptText = inputTranscription["text"] as? String,
           !transcriptText.isEmpty {
            onResponse?(.inputTranscription(transcriptText))
        }

        // Check for top-level outputTranscription
        if let outputTranscription = json["outputTranscription"] as? [String: Any],
           let transcriptText = outputTranscription["text"] as? String,
           !transcriptText.isEmpty {
            onResponse?(.outputTranscription(transcriptText))
        }

        // Check for serverContent
        if let serverContent = json["serverContent"] as? [String: Any] {
            // Parse model turn parts (audio inline data + any text)
            if let modelTurn = serverContent["modelTurn"] as? [String: Any],
               let parts = modelTurn["parts"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String {
                        onResponse?(.text(text))
                    }
                    if let inlineData = part["inlineData"] as? [String: Any],
                       let b64 = inlineData["data"] as? String,
                       let audioData = Data(base64Encoded: b64) {
                        onResponse?(.audio(audioData))
                    }
                }
            }

            // Parse output transcription inside serverContent (legacy/fallback)
            if let outputTranscription = serverContent["outputTranscription"] as? [String: Any],
               let transcriptText = outputTranscription["text"] as? String,
               !transcriptText.isEmpty {
                onResponse?(.outputTranscription(transcriptText))
            }

            // Parse input transcription inside serverContent (legacy/fallback)
            if let inputTranscription = serverContent["inputTranscription"] as? [String: Any],
               let transcriptText = inputTranscription["text"] as? String,
               !transcriptText.isEmpty {
                onResponse?(.inputTranscription(transcriptText))
            }

            // Check turnComplete
            if let turnComplete = serverContent["turnComplete"] as? Bool, turnComplete {
                onResponse?(.turnComplete)
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension GeminiLiveClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let msg = "✅ GeminiLiveClient: WebSocket opened"
        print(msg)
        logToFile(msg)
        setState(.connected)
        sendSetupMessage()
        startReceiveLoop()
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        let msg = "🔌 GeminiLiveClient: WebSocket closed (code: \(closeCode.rawValue), reason: \(reasonStr))"
        print(msg)
        logToFile(msg)
        setState(.disconnected)
        onDisconnect?(nil)
    }
}
