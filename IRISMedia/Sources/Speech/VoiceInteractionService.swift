import Foundation
import Speech
import AVFoundation
import IRISCore

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
    // removed deepgramService
    private var audioEngine: AVAudioEngine?
    private var lastTranscriptionTime: Date?
    private var silenceCheckTimer: Timer?
    private var currentTranscript: String = ""

    private let silenceThreshold: TimeInterval = 2.5
    private var isUsingExternalAudio = false

    /// Delegate for ICOI voice commands
    public weak var icoiDelegate: ICOIVoiceCommandDelegate?
    
    /// Callback for raw audio buffers (for streaming/processing externally)
    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

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
        print("🎤 startRecordingWithExternalAudio: START (SFSpeechRecognizer)")

        // Reset flags
        speechDetectedCallbackCalled = false
        completionCalled = false
        
        // Cancel existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create new request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            completion("")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        if #available(macOS 14, *) {
             recognitionRequest.customizedLanguageModel = nil
        }
        
        // Keep reference
        let request = recognitionRequest

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.currentTranscript = result.bestTranscription.formattedString
                let text = self.currentTranscript
                isFinal = result.isFinal
                
                if !text.isEmpty {
                    self.lastTranscriptionTime = Date()
                    onPartialResult?(text)
                    
                    if !self.speechDetectedCallbackCalled {
                         self.speechDetectedCallbackCalled = true
                         self.timeoutTimer?.invalidate()
                         self.timeoutTimer = nil
                         print("⏱️ Speech detected (SFSpeech Internal) - cancelled timeout timer")
                         onSpeechDetected?()
                    }
                }
            }
            
            if error != nil || isFinal {
                if isFinal {
                    request.endAudio()
                }
            }
        }
        
        print("🎤 startRecordingWithExternalAudio: SFSpeechRecognizer started")
        lastTranscriptionTime = nil
        startSilenceDetectionNoNode(completion: completion, transcribedTextGetter: { [weak self] in
            return self?.currentTranscript ?? ""
        })
        
        if let timeout = timeout {
            print("⏱️ startRecordingWithExternalAudio: Setting timer for \(timeout)s")
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                print("⏱️ startRecordingWithExternalAudio: Timeout reached")
                let finalTranscription = self?.currentTranscript ?? ""
                self?.stopRecordingInternalNoNode(completion: completion, transcribedText: finalTranscription)
            }
        }
    }
    public func receiveBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isUsingExternalAudio else { return }
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
        
        Task {
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest?.endAudio()
            recognitionRequest = nil
        }
        
        lastTranscriptionTime = nil
        print("🎤🎤🎤 CALLING COMPLETION CALLBACK WITH: '\(transcribedText)'")
        completion(transcribedText)
    }

    private var timeoutTimer: Timer?
    private var speechDetectedCallbackCalled = false
    private var completionCalled = false

    private func startRecording(timeout: TimeInterval?, onSpeechDetected: (() -> Void)?, onPartialResult: ((String) -> Void)?, completion: @escaping (String) -> Void) {
        // Reset flags
        speechDetectedCallbackCalled = false
        completionCalled = false
        currentTranscript = ""
        
        // Cancel existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Audio Engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            completion("")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            completion("")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        if #available(macOS 14, *) {
            recognitionRequest.customizedLanguageModel = nil
        }
        
        // Task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            var isFinal = false
            
            if let result = result {
                self.currentTranscript = result.bestTranscription.formattedString
                isFinal = result.isFinal
                
                if !self.currentTranscript.isEmpty {
                    self.lastTranscriptionTime = Date()
                    onPartialResult?(self.currentTranscript)
                    
                    if !self.speechDetectedCallbackCalled {
                        self.speechDetectedCallbackCalled = true
                        self.timeoutTimer?.invalidate()
                        self.timeoutTimer = nil
                        print("⏱️ Speech detected (SFSpeech Internal) - cancelled timeout timer")
                        onSpeechDetected?()
                    }
                }
            }
            
            if error != nil || isFinal {
                self.audioEngine?.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        // Tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            self?.recognitionRequest?.append(buffer)
            self?.onAudioBuffer?(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("🎤 SFSpeechRecognizer (Internal) started")
        } catch {
            print("❌ AudioEngine start error: \(error)")
            completion("")
        }
        
        lastTranscriptionTime = nil
        // Used logic similar to NoNode but we have a Node here, keeping consistent logic for now
        // But we need to handle silence detection.
        // We can reuse startSilenceDetectionNoNode or similar logic.
        startSilenceDetectionNoNode(completion: completion, transcribedTextGetter: { [weak self] in
            return self?.currentTranscript ?? ""
        })
        
        if let timeout = timeout {
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                let text = self?.currentTranscript ?? ""
                self?.stopRecordingInternalNoNode(completion: completion, transcribedText: text)
            }
        }
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

        Task {
            // deepgramService cleanup removed
        }

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
