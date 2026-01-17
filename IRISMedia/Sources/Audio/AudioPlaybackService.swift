import AVFoundation

public class AudioPlaybackService: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?

    private var audioQueue: [Data] = []
    private var isProcessingQueue = false

    @Published public var isPlaying = false

    public var onPlaybackStarted: (() -> Void)?
    public var onPlaybackStopped: (() -> Void)?

    public init() {}

    public func setup(sampleRate: Double = 24000, channels: UInt32 = 1) throws {
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        ) else {
            throw AudioPlaybackError.invalidFormat
        }

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        try engine.start()

        self.audioEngine = engine
        self.playerNode = playerNode
        self.audioFormat = format

        print("🔊 AudioPlaybackService: Setup complete (sampleRate: \(sampleRate))")
    }

    public func enqueue(_ pcmData: Data) {
        audioQueue.append(pcmData)
        processQueue()
    }

    public func play() {
        playerNode?.play()
        isPlaying = true
        onPlaybackStarted?()
    }

    public func stop() {
        playerNode?.stop()
        audioQueue.removeAll()
        isPlaying = false
        onPlaybackStopped?()
        print("🔇 AudioPlaybackService: Stopped (barge-in)")
    }

    public func clearQueue() {
        audioQueue.removeAll()
    }

    private func processQueue() {
        guard !isProcessingQueue else { return }
        guard !audioQueue.isEmpty else { return }
        guard let playerNode = playerNode, let format = audioFormat else { return }

        isProcessingQueue = true

        // Start playback FIRST, then schedule buffers — eliminates startup latency.
        // AVAudioPlayerNode plays scheduled buffers in order; scheduling after play() is fine.
        if !playerNode.isPlaying {
            play()
        }

        while !audioQueue.isEmpty {
            let pcmData = audioQueue.removeFirst()

            guard let buffer = createBuffer(from: pcmData, format: format) else {
                continue
            }

            playerNode.scheduleBuffer(buffer) { [weak self] in
                Task { @MainActor in
                    if self?.audioQueue.isEmpty == true && self?.playerNode?.isPlaying == false {
                        self?.isPlaying = false
                        self?.onPlaybackStopped?()
                    }
                }
            }
        }

        isProcessingQueue = false
    }

    private func createBuffer(from data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / 2

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            if let int16Ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self),
               let channelData = buffer.int16ChannelData {
                channelData[0].update(from: int16Ptr, count: Int(frameCount))
            }
        }

        return buffer
    }

    deinit {
        audioEngine?.stop()
    }
}

public enum AudioPlaybackError: Error {
    case invalidFormat
    case engineNotStarted
}
