import AVFoundation

@MainActor
public class AudioService: NSObject, ObservableObject {
    public override init() {
        super.init()
    }

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    @Published public var isListening = false
    @Published public var voiceActivityDetected = false
    @Published public var audioLevel: Float = 0
    
    private var silenceThreshold: Float = 0.01
    private var silenceFrameCount = 0
    private var maxSilenceFrames = 30
    
    public var onVoiceStart: (() -> Void)?
    public var onVoiceEnd: (() -> Void)?
    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    public func start() async throws {
        guard await checkPermission() else {
            throw AudioError.permissionDenied
        }
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }
        
        try engine.start()
        
        self.audioEngine = engine
        self.inputNode = inputNode
        isListening = true
    }
    
    public func stop() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        isListening = false
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let level = sum / Float(frameLength)
        
        Task { @MainActor in
            self.audioLevel = level
            
            if level > self.silenceThreshold {
                if !self.voiceActivityDetected {
                    self.voiceActivityDetected = true
                    self.onVoiceStart?()
                }
                self.silenceFrameCount = 0
            } else if self.voiceActivityDetected {
                self.silenceFrameCount += 1
                if self.silenceFrameCount > self.maxSilenceFrames {
                    self.voiceActivityDetected = false
                    self.onVoiceEnd?()
                }
            }
        }
        
        if voiceActivityDetected {
            onAudioBuffer?(buffer)
        }
    }
    
    private func checkPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }
}

public enum AudioError: Error {
    case permissionDenied
}
