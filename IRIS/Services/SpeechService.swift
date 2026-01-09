import Speech
import AVFoundation

@MainActor
class SpeechService: ObservableObject {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var transcript = ""
    @Published var isRecognizing = false
    @Published var isFinal = false
    
    var onTranscriptUpdate: ((String, Bool) -> Void)?
    
    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    func startRecognition() throws {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }
        
        recognitionTask?.cancel()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        
        recognitionRequest = request
        isRecognizing = true
        isFinal = false
        transcript = ""
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                    self.isFinal = result.isFinal
                    self.onTranscriptUpdate?(self.transcript, result.isFinal)
                    
                    if result.isFinal {
                        self.isRecognizing = false
                    }
                }
            }
            
            if error != nil {
                Task { @MainActor in
                    self.stopRecognition()
                }
            }
        }
    }
    
    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    func stopRecognition() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecognizing = false
    }
    
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

enum SpeechError: Error {
    case recognizerUnavailable
    case notAuthorized
}
