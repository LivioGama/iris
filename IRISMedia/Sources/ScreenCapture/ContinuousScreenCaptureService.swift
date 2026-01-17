import ScreenCaptureKit
import AppKit
import CoreGraphics
import CoreMedia

// MARK: - Captured Frame

public struct CapturedFrame: Sendable {
    public let image: CGImage
    public let timestamp: Date
    public let jpegBase64: String
}

// MARK: - ContinuousScreenCaptureService
/// Captures screen frames continuously at ~1 FPS using SCStream
/// Maintains a circular buffer of recent frames for instant retrieval.
/// Thread-safe — all mutable state protected by lock.
public class ContinuousScreenCaptureService: NSObject {
    // MARK: - Properties

    public var isCapturing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCapturing
    }

    /// Latest captured frame, ready for instant retrieval
    public var latestFrame: CapturedFrame? {
        lock.lock()
        defer { lock.unlock() }
        return frameBuffer.last
    }

    /// Current gaze point to overlay on the frame (in screen coordinates)
    public var gazePoint: CGPoint? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _gazePoint
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _gazePoint = newValue
        }
    }

    /// Preferred screen to capture (e.g., the screen the user is looking at)
    public var preferredScreen: NSScreen?

    private var _isCapturing = false
    private var _isPaused = false
    private var _gazePoint: CGPoint?
    private var displayFrame: CGRect = .zero
    private var stream: SCStream?
    private var streamOutput: StreamOutputHandler?
    private let bufferSize = 5
    private var frameBuffer: [CapturedFrame] = []
    private let lock = NSLock()
    private let jpegQuality: CGFloat = 0.25
    private let idleMaxDimension: Int = 1280
    private let verboseLogsEnabled = ProcessInfo.processInfo.environment["IRIS_VERBOSE_LOGS"] == "1"
    private var lastDebugFrameWriteTime: Date = .distantPast
    private let debugFrameWriteInterval: TimeInterval = 5.0

    private var lastFrameTime: Date = .distantPast

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: false])

    private var lastFrameSignature: [UInt8]?
    private let frameDiffThreshold: Int = 10

    public override init() {
        super.init()
    }

    // MARK: - Start / Stop

    public func start() async throws {
        guard !isCapturing else { return }

        let content = try await SCShareableContent.current

        // Use preferredScreen if set, otherwise fall back to first display
        var targetDisplay: SCDisplay?
        if let preferredScreen = preferredScreen {
            let screenNumber = preferredScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            targetDisplay = content.displays.first(where: { $0.displayID == (screenNumber ?? 0) })
            print("📹 ContinuousScreenCapture: Using preferred screen \(preferredScreen.localizedName)")
        }

        guard let display = targetDisplay ?? content.displays.first else {
            throw ScreenCaptureError.noDisplay
        }

        self.displayFrame = CGRect(x: CGFloat(display.frame.origin.x), y: CGFloat(display.frame.origin.y), width: CGFloat(display.width), height: CGFloat(display.height))

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let nativeWidth = Int(display.width)
        let nativeHeight = Int(display.height)
        let (captureWidth, captureHeight) = scaledDimensions(
            width: nativeWidth,
            height: nativeHeight,
            maxDimension: idleMaxDimension
        )

        let config = SCStreamConfiguration()
        // Keep idle stream lightweight; high-res snapshots are captured on-demand at voice start.
        config.width = captureWidth
        config.height = captureHeight
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // ~1 FPS
        config.queueDepth = 3

        let handler = StreamOutputHandler { [weak self] sampleBuffer in
            self?.handleFrame(sampleBuffer)
        }
        self.streamOutput = handler

        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(handler, type: .screen, sampleHandlerQueue: DispatchQueue(label: "iris.screen.capture", qos: .userInitiated))
        try await newStream.startCapture()

        self.stream = newStream

        lock.lock()
        _isCapturing = true
        lock.unlock()

        print("📹 ContinuousScreenCaptureService: Started (1 FPS, \(config.width)×\(config.height), native \(nativeWidth)×\(nativeHeight))")
    }

    public func stop() {
        guard isCapturing else { return }

        Task {
            try? await stream?.stopCapture()
            if let output = streamOutput {
                try? stream?.removeStreamOutput(output, type: .screen)
            }
            stream = nil
            streamOutput = nil

            lock.lock()
            frameBuffer.removeAll()
            _isCapturing = false
            _isPaused = false
            lock.unlock()

            print("📹 ContinuousScreenCaptureService: Stopped")
        }
    }

    /// Pause capture without stopping the stream (saves CPU/memory)
    public func pause() {
        lock.lock()
        _isPaused = true
        lock.unlock()
        print("⏸️ ContinuousScreenCaptureService: Paused")
    }

    /// Resume capture
    public func resume() {
        lock.lock()
        _isPaused = false
        lock.unlock()
        print("▶️ ContinuousScreenCaptureService: Resumed")
    }

    // MARK: - Frame Processing

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        let paused = _isPaused
        lock.unlock()

        if paused { return }

        let now = Date()
        guard now.timeIntervalSince(lastFrameTime) >= 0.9 else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let signature = computeFrameSignature(pixelBuffer)
        if let lastSig = lastFrameSignature, isSignatureSimilar(signature, lastSig) {
            return
        }
        lastFrameSignature = signature

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        var finalCGImage = cgImage

        // Overlay gaze if available
        if let globalGaze = self.gazePoint {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            nsImage.lockFocus()

            // Convert global gaze to display-local coordinates
            // SCStream captures a display; globalGaze is in screen coordinates (bottom-left origin)
            let localX = globalGaze.x - displayFrame.origin.x
            let localY = globalGaze.y - displayFrame.origin.y

            let dotRadius: CGFloat = 12
            let dotRect = NSRect(x: localX - dotRadius, y: localY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)

            let path = NSBezierPath(ovalIn: dotRect)
            NSColor.orange.withAlphaComponent(0.6).setFill()
            path.fill()

            NSColor.white.withAlphaComponent(0.4).setStroke()
            path.lineWidth = 1.5
            path.stroke()

            nsImage.unlockFocus()
            if let overlaid = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                finalCGImage = overlaid
            }
        }

        let bitmapRep = NSBitmapImageRep(cgImage: finalCGImage)
        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) {
            if verboseLogsEnabled, now.timeIntervalSince(lastDebugFrameWriteTime) >= debugFrameWriteInterval {
                lastDebugFrameWriteTime = now
                try? jpegData.write(to: URL(fileURLWithPath: "/tmp/iris_continuous_debug.jpg"))
            }
            let jpegBase64 = jpegData.base64EncodedString()
            let frame = CapturedFrame(image: finalCGImage, timestamp: now, jpegBase64: jpegBase64)

            lock.lock()
            frameBuffer.append(frame)
            if frameBuffer.count > bufferSize {
                frameBuffer.removeFirst(frameBuffer.count - bufferSize)
            }
            lock.unlock()
        }
    }

    private func computeFrameSignature(_ pixelBuffer: CVPixelBuffer) -> [UInt8] {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return [] }

        let stepX = max(width / 8, 1)
        let stepY = max(height / 8, 1)
        var signature = [UInt8]()
        signature.reserveCapacity(64)

        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                let offset = y * bytesPerRow + x * 4
                let ptr = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                signature.append(ptr[0])
                signature.append(ptr[1])
                signature.append(ptr[2])
            }
        }
        return signature
    }

    private func isSignatureSimilar(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count, !a.isEmpty else { return false }
        var diffCount = 0
        for i in 0..<a.count {
            if abs(Int(a[i]) - Int(b[i])) > 20 {
                diffCount += 1
            }
        }
        return diffCount < frameDiffThreshold
    }

    private func cgImageToJPEGBase64(_ image: CGImage) -> String? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }

    private func scaledDimensions(width: Int, height: Int, maxDimension: Int) -> (Int, Int) {
        guard width > 0, height > 0 else { return (width, height) }
        let largest = max(width, height)
        guard largest > maxDimension else { return (width, height) }

        let scale = Double(maxDimension) / Double(largest)
        let scaledWidth = max(1, Int((Double(width) * scale).rounded()))
        let scaledHeight = max(1, Int((Double(height) * scale).rounded()))
        return (scaledWidth, scaledHeight)
    }
}

// MARK: - SCStreamOutput Handler

private class StreamOutputHandler: NSObject, SCStreamOutput {
    private let handler: (CMSampleBuffer) -> Void

    init(handler: @escaping (CMSampleBuffer) -> Void) {
        self.handler = handler
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        handler(sampleBuffer)
    }
}
