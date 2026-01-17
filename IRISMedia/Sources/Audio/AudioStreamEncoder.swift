import AVFoundation

// MARK: - AudioStreamEncoder
/// Converts native audio buffers (44.1kHz/48kHz float32) to PCM16 16kHz mono
/// base64 chunks suitable for the Gemini Live API
public class AudioStreamEncoder {
    // MARK: - Properties

    /// Called when an encoded chunk is ready (base64 PCM16 16kHz mono)
    public var onEncodedChunk: ((String) -> Void)?

    private let targetSampleRate: Double = 16000
    private let targetChannels: AVAudioChannelCount = 1
    private let flushThreshold: Int = 1600  // ~100ms of samples at 16kHz (ultra-low latency)

    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat
    private var sampleAccumulator: [Int16] = []
    private let lock = NSLock()

    // MARK: - Init

    public init() {
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        )!
        sampleAccumulator.reserveCapacity(flushThreshold * 2)
    }

    // MARK: - Process

    /// Process an incoming audio buffer and produce base64 PCM16 chunks
    public func processBuffer(_ buffer: AVAudioPCMBuffer) {
        let inputFormat = buffer.format

        // Lazily create converter matching input format
        if converter == nil || converter!.inputFormat != inputFormat {
            guard let newConverter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                print("❌ AudioStreamEncoder: Failed to create converter from \(inputFormat) to \(outputFormat)")
                return
            }
            newConverter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Normal
            self.converter = newConverter
        }

        guard let converter = converter else { return }

        // Calculate output frame capacity
        let ratio = targetSampleRate / inputFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
        guard outputFrameCapacity > 0 else { return }

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
            return
        }

        var error: NSError?
        var inputConsumed = false

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error = error {
            print("⚠️ AudioStreamEncoder: Conversion error: \(error.localizedDescription)")
            return
        }

        guard outputBuffer.frameLength > 0,
              let int16Data = outputBuffer.int16ChannelData else { return }

        let frameCount = Int(outputBuffer.frameLength)

        lock.lock()
        // Append converted samples
        for i in 0..<frameCount {
            sampleAccumulator.append(int16Data[0][i])
        }

        // Flush if we have enough (~1 second)
        if sampleAccumulator.count >= flushThreshold {
            let chunk = Array(sampleAccumulator.prefix(flushThreshold))
            sampleAccumulator.removeFirst(min(flushThreshold, sampleAccumulator.count))
            lock.unlock()

            flushChunk(chunk)
        } else {
            lock.unlock()
        }
    }

    /// Flush any remaining buffered samples
    public func flush() {
        lock.lock()
        let remaining = sampleAccumulator
        sampleAccumulator.removeAll(keepingCapacity: true)
        lock.unlock()

        if !remaining.isEmpty {
            flushChunk(remaining)
        }
    }

    /// Reset encoder state
    public func reset() {
        lock.lock()
        sampleAccumulator.removeAll(keepingCapacity: true)
        converter = nil
        lock.unlock()
    }

    // MARK: - Private

    private func flushChunk(_ samples: [Int16]) {
        // Convert Int16 array to Data then base64
        let data = samples.withUnsafeBufferPointer { bufferPointer in
            Data(buffer: bufferPointer)
        }
        let base64 = data.base64EncodedString()
        onEncodedChunk?(base64)
    }
}
