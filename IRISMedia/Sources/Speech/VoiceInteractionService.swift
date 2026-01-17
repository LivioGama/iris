import Foundation
import Speech
import AVFoundation

/// Delegate protocol for ICOI voice command actions
public protocol ICOIVoiceCommandDelegate: AnyObject {
    func didReceiveICOICommand(_ command: ICOIVoiceCommand)
}

/// ICOI voice commands that can be triggered by voice
public enum ICOIVoiceCommand {
    case useOption(number: Int)
    case copyOption(number: Int)
    case copyCode
    case exportSummary
    case showMore
}

/// Manages speech recognition with automatic silence detection
/// Responsibility: Speech recognition orchestration
public class VoiceInteractionService: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var lastTranscriptionTime: Date?
    private var silenceCheckTimer: Timer?

    private let silenceThreshold: TimeInterval = 2.5
    private var isUsingExternalAudio = false

    /// Delegate for ICOI voice commands
    public weak var icoiDelegate: ICOIVoiceCommandDelegate?

    public override init() {
        super.init()
    }

    /// Pre-warms the service by requesting authorization early
    public func prewarm() {
        SFSpeechRecognizer.requestAuthorization { status in
            print("🎤 Speech recognition pre-warmed: \(status)")
        }
    }

    ///   - onPartialResult: Called with partial transcription as words are recognized in real-time
    ///   - completion: Called with transcribed text when user stops speaking
    public func startListening(timeout: TimeInterval? = nil, useExternalAudio: Bool = false, onSpeechDetected: (() -> Void)? = nil, onPartialResult: ((String) -> Void)? = nil, completion: @escaping (String) -> Void) {
        self.isUsingExternalAudio = useExternalAudio

        if useExternalAudio {
            SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if authStatus == .authorized {
                        self.startRecordingWithExternalAudio(timeout: timeout, onSpeechDetected: onSpeechDetected, onPartialResult: onPartialResult, completion: completion)
                    } else {
                        completion("")
                    }
                }
            }
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startRecording(timeout: timeout, onSpeechDetected: onSpeechDetected, onPartialResult: onPartialResult, completion: completion)
                case .denied, .restricted, .notDetermined:
                    print("❌ Speech recognition not authorized")
                    completion("")
                @unknown default:
                    completion("")
                }
            }
        }
    }

    private func startRecordingWithExternalAudio(timeout: TimeInterval?, onSpeechDetected: (() -> Void)?, onPartialResult: ((String) -> Void)?, completion: @escaping (String) -> Void) {
        print("🎤 startRecordingWithExternalAudio: START")

        // Reset flags for new recording session
        speechDetectedCallbackCalled = false
        completionCalled = false

        recognitionTask?.cancel()
        recognitionTask = nil
        print("🎤 startRecordingWithExternalAudio: Creating request")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ startRecordingWithExternalAudio: Failed to create request")
            completion("")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        var transcribedText = ""
        print("🎤 startRecordingWithExternalAudio: Starting recognition task")
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                transcribedText = result.bestTranscription.formattedString
                self.lastTranscriptionTime = Date()

                // Stream partial results in real-time
                onPartialResult?(transcribedText)

                if !self.speechDetectedCallbackCalled && !transcribedText.isEmpty {
                    self.speechDetectedCallbackCalled = true
                    onSpeechDetected?()
                }
                self.startSilenceDetectionNoNode(completion: completion, transcribedTextGetter: { transcribedText })
            }
            if error != nil {
                print("❌ startRecordingWithExternalAudio: TASK ERROR: \(error!.localizedDescription)")
                self.stopRecordingInternalNoNode(completion: completion, transcribedText: transcribedText)
            }
        }
        print("🎤 startRecordingWithExternalAudio: Task started = \(recognitionTask != nil)")
        lastTranscriptionTime = nil
        startSilenceDetectionNoNode(completion: completion, transcribedTextGetter: { transcribedText })
        if let timeout = timeout {
            print("⏱️ startRecordingWithExternalAudio: Setting timer for \(timeout)s")
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                print("⏱️ startRecordingWithExternalAudio: Timeout reached")
                self?.stopRecordingInternalNoNode(completion: completion, transcribedText: transcribedText)
            }
        }
    }

    public func receiveBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isUsingExternalAudio && recognitionRequest != nil else { return }
        recognitionRequest?.append(buffer)
    }

    private func startSilenceDetectionNoNode(completion: @escaping (String) -> Void, transcribedTextGetter: @escaping () -> String) {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let transcribedText = transcribedTextGetter()
            if let lastTime = self.lastTranscriptionTime, !transcribedText.isEmpty, Date().timeIntervalSince(lastTime) >= self.silenceThreshold {
                timer.invalidate()
                self.stopRecordingInternalNoNode(completion: completion, transcribedText: transcribedText)
            }
        }
    }

    private func stopRecordingInternalNoNode(completion: @escaping (String) -> Void, transcribedText: String) {
        // Prevent calling completion multiple times
        guard !completionCalled else {
            print("⚠️ Completion already called, skipping duplicate callback")
            return
        }
        completionCalled = true

        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        lastTranscriptionTime = nil
        print("🎤🎤🎤 CALLING COMPLETION CALLBACK WITH: '\(transcribedText)'")
        completion(transcribedText)
    }

    private var timeoutTimer: Timer?
    private var speechDetectedCallbackCalled = false
    private var completionCalled = false

    private func startRecording(timeout: TimeInterval?, onSpeechDetected: (() -> Void)?, onPartialResult: ((String) -> Void)?, completion: @escaping (String) -> Void) {
        // Reset flags for new recording session
        speechDetectedCallbackCalled = false
        completionCalled = false

        // Prevent concurrent recordings
        if audioEngine?.isRunning == true {
            print("⚠️ Audio engine already running, skipping")
            completion("")
            return
        }

        // 1. Reset/Create fresh audio engine to avoid state issues
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
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
        var transcribedText = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                transcribedText = result.bestTranscription.formattedString
                self.lastTranscriptionTime = Date()

                // Stream partial results in real-time
                onPartialResult?(transcribedText)

                // Call speech detected callback on first transcription
                if !self.speechDetectedCallbackCalled && !transcribedText.isEmpty {
                    self.speechDetectedCallbackCalled = true
                    onSpeechDetected?()
                }

                // Start/restart silence detection timer
                self.startSilenceDetection(completion: completion, inputNode: inputNode, transcribedTextGetter: { transcribedText })
            }

            // Only stop on error - let silence detection handle normal completion
            if error != nil {
                print("❌ Speech recognition error: \(error!.localizedDescription)")
                self.stopRecordingInternal(completion: completion, inputNode: inputNode, transcribedText: transcribedText)
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Ensure any previous tap is removed before installing a new one
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            print("🎤 Listening... (will stop automatically after silence)")

            // Don't initialize lastTranscriptionTime - will be set when user speaks
            lastTranscriptionTime = nil
            startSilenceDetection(completion: completion, inputNode: inputNode, transcribedTextGetter: { transcribedText })

            // Set up timeout if specified
            if let timeout = timeout {
                print("⏱️ Timeout set to \(timeout) seconds")
                timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    print("⏱️ Timeout reached, stopping with current transcription")
                    self.stopRecordingInternal(completion: completion, inputNode: inputNode, transcribedText: transcribedText)
                }
            }
        } catch {
            print("❌ Audio engine failed to start: \(error)")
            completion("")
        }
    }

    private func startSilenceDetection(completion: @escaping (String) -> Void, inputNode: AVAudioNode, transcribedTextGetter: @escaping () -> String) {
        // Cancel existing timer
        silenceCheckTimer?.invalidate()

        // Check for silence repeatedly every 0.5 seconds
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let transcribedText = transcribedTextGetter()

            // Only stop if we've received some transcription AND been silent for threshold
            if let lastTime = self.lastTranscriptionTime,
               !transcribedText.isEmpty,
               Date().timeIntervalSince(lastTime) >= self.silenceThreshold {
                print("🔇 Silence detected after speech, stopping recording")
                timer.invalidate()
                self.stopRecordingInternal(completion: completion, inputNode: inputNode, transcribedText: transcribedText)
            }
        }
    }

    private func stopRecordingInternal(completion: @escaping (String) -> Void, inputNode: AVAudioNode, transcribedText: String) {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        audioEngine?.stop()
        inputNode.removeTap(onBus: 0)
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil

        lastTranscriptionTime = nil

        print("🛑 Recording stopped: '\(transcribedText)'")
        print("🎤🎤🎤 CALLING COMPLETION CALLBACK WITH: '\(transcribedText)'")
        completion(transcribedText)
    }

    /// Stops listening immediately
    public func stopListening() {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        if let engine = audioEngine, engine.isRunning {
            let inputNode = engine.inputNode
            inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        lastTranscriptionTime = nil
        speechDetectedCallbackCalled = false

        print("🛑 Listening stopped manually")
    }

    /// Returns true if currently listening
    public var isListening: Bool {
        if isUsingExternalAudio {
            return recognitionRequest != nil
        }
        return audioEngine?.isRunning ?? false
    }

    /// Detects ICOI voice commands in user input
    private func detectICOICommand(in input: String) -> ICOIVoiceCommand? {
        let normalizedInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // "use option X" or "select option X" or "choose option X"
        if let optionNumber = extractOptionNumber(from: normalizedInput, patterns: ["use option", "select option", "choose option", "option"]) {
            return .useOption(number: optionNumber)
        }

        // "copy option X"
        if let optionNumber = extractOptionNumber(from: normalizedInput, patterns: ["copy option"]) {
            return .copyOption(number: optionNumber)
        }

        // "copy code" or "copy the code"
        if normalizedInput == "copy code" || normalizedInput == "copy the code" {
            return .copyCode
        }

        // "export summary" or "export" or "save summary"
        if normalizedInput == "export summary" || normalizedInput == "export" || normalizedInput == "save summary" {
            return .exportSummary
        }

        // "show more" or "expand"
        if normalizedInput == "show more" || normalizedInput == "expand" {
            return .showMore
        }

        return nil
    }

    /// Extracts option number from command patterns
    private func extractOptionNumber(from input: String, patterns: [String]) -> Int? {
        for pattern in patterns {
            if let range = input.range(of: pattern),
               let numberString = input[range.upperBound...].trimmingCharacters(in: .whitespaces).first,
               let number = Int(String(numberString)) {
                return number
            }
        }
        return nil
    }

    /// Returns confirmation message for ICOI commands
    private func confirmationMessage(for command: ICOIVoiceCommand) -> String {
        switch command {
        case .useOption(let number):
            return "Selected option \(number)"
        case .copyOption(let number):
            return "Copied option \(number)"
        case .copyCode:
            return "Code copied to clipboard"
        case .exportSummary:
            return "Summary exported"
        case .showMore:
            return "Expanded view"
        }
    }
}
