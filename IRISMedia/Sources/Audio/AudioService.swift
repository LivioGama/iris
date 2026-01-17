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
        print("🎤 AudioService: Starting...")
        guard await checkPermission() else {
            print("❌ AudioService: Permission denied")
            throw AudioError.permissionDenied
        }
        
        print("🎤 AudioService: Creating engine...")
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        print("🎤 AudioService: Input format: \(format)")
        
        print("🎤 AudioService: Installing tap...")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }
        
        print("🎤 AudioService: Starting engine...")
        try engine.start()
        
        self.audioEngine = engine
        self.inputNode = inputNode
        isListening = true
        print("✅ AudioService: Started successfully")
    }
    
    public func stop() {
        print("🔇 AudioService: Stopping engine and removing tap")
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        inputNode = nil
        audioEngine = nil
        isListening = false
        voiceActivityDetected = false
        isVoiceActiveInternal = false
        silenceFrameCount = 0
    }
    
    private var isVoiceActiveInternal = false

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let level = sum / Float(frameLength)
        
        // Detect voice activity change on this thread
        var voiceStarted = false
        var voiceEnded = false
        
        if level > self.silenceThreshold {
            if !self.isVoiceActiveInternal {
                self.isVoiceActiveInternal = true
                voiceStarted = true
            }
            self.silenceFrameCount = 0
        } else if self.isVoiceActiveInternal {
            self.silenceFrameCount += 1
            if self.silenceFrameCount > self.maxSilenceFrames {
                self.isVoiceActiveInternal = false
                voiceEnded = true
            }
        }
        
        // Dispatch UI updates and callbacks to MainActor
        Task { @MainActor in
            self.audioLevel = level
            if voiceStarted {
                self.voiceActivityDetected = true
                self.onVoiceStart?()
            }
            if voiceEnded {
                self.voiceActivityDetected = false
                self.onVoiceEnd?()
            }
        }
        
        // Forward buffer if voice is active
        if isVoiceActiveInternal {
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
