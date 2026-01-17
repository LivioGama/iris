import Foundation
import Speech
import AVFoundation

/// Manages speech recognition with automatic silence detection
/// Responsibility: Speech recognition orchestration
public class VoiceInteractionService: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var lastTranscriptionTime: Date?
    private var silenceCheckTimer: Timer?

    private let silenceThreshold: TimeInterval = 2.5

    public override init() {
        super.init()
    }

    /// Starts speech recognition with automatic silence detection
    /// - Parameters:
    ///   - timeout: Optional timeout in seconds. If nil, no timeout is applied.
    ///   - completion: Called with transcribed text when user stops speaking
    public func startListening(timeout: TimeInterval? = nil, completion: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startRecording(timeout: timeout, completion: completion)
                case .denied, .restricted, .notDetermined:
                    print("❌ Speech recognition not authorized")
                    completion("")
                @unknown default:
                    completion("")
                }
            }
        }
    }

    private var timeoutTimer: Timer?

    private func startRecording(timeout: TimeInterval?, completion: @escaping (String) -> Void) {
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
        var transcribedText = ""

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                transcribedText = result.bestTranscription.formattedString
                self.lastTranscriptionTime = Date()

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

        audioEngine.stop()
        inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil

        lastTranscriptionTime = nil

        print("🛑 Recording stopped: '\(transcribedText)'")
        completion(transcribedText)
    }

    /// Stops listening immediately
    public func stopListening() {
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil

        timeoutTimer?.invalidate()
        timeoutTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        lastTranscriptionTime = nil

        print("🛑 Listening stopped manually")
    }

    /// Returns true if currently listening
    public var isListening: Bool {
        return audioEngine.isRunning
    }
}
