import AVFoundation
import CoreImage
import AppKit

public class CameraService: NSObject, ObservableObject {
    public override init() {
        super.init()
    }

    @MainActor @Published public var currentFrame: CIImage?
    @MainActor @Published public var isRunning = false
    
    /// Latest captured frame, ready for instant retrieval
    public var latestFrame: CapturedFrame? {
        lock.lock()
        defer { lock.unlock() }
        return _latestFrame
    }
    
    private var _latestFrame: CapturedFrame?
    private let lock = NSLock()
    private var _onFrame: (@Sendable (CVPixelBuffer) -> Void)?
    
    public var onFrame: (@Sendable (CVPixelBuffer) -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _onFrame }
        set { lock.lock(); _onFrame = newValue; lock.unlock() }
    }
    
    private var captureSession: AVCaptureSession?
    private let processingQueue = DispatchQueue(label: "camera.processing")
    
    @MainActor
    public func start() async throws {
        guard await checkPermission() else {
            throw CameraError.permissionDenied
        }
        
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720
        
        // Prefer MacBook Pro Camera as it fronts the user
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        ).devices

        let preferredDevice = devices.first { $0.localizedName.contains("MacBook") } ??
                              devices.first { !$0.localizedName.lowercased().contains("immersed") && !$0.localizedName.lowercased().contains("virtual") } ??
                              devices.first
        
        guard let device = preferredDevice,
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw CameraError.deviceNotAvailable
        }
        
        print("📸 CameraService: Using device: \(device.localizedName)")
        
        try? device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
        device.unlockForConfiguration()
        
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: processingQueue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        session.addOutput(output)
        
        captureSession = session
        session.startRunning()
        isRunning = true
        print("📸 CameraService: Started at 15fps (reduced from 30fps for performance)")
    }
    
    @MainActor
    public func stop() {
        captureSession?.stopRunning()
        isRunning = false
    }
    
    private func checkPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.onFrame?(pixelBuffer)
        
        let now = Date()
        
        // Convert to CapturedFrame for Gemini Live API
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.3]) {
                let jpegBase64 = jpegData.base64EncodedString()
                let frame = CapturedFrame(image: cgImage, timestamp: now, jpegBase64: jpegBase64)
                
                lock.lock()
                _latestFrame = frame
                lock.unlock()
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        Task { @MainActor in
             self.currentFrame = ciImage
        }
    }
}

public enum CameraError: Error {
    case permissionDenied
    case deviceNotAvailable
}
