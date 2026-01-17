import AVFoundation
import CoreImage

public class CameraService: NSObject, ObservableObject {
    public override init() {
        super.init()
    }

    @MainActor @Published public var currentFrame: CIImage?
    @MainActor @Published public var isRunning = false
    
    private let sessionLock = NSLock()
    private var _onFrame: (@Sendable (CVPixelBuffer) -> Void)?
    
    public var onFrame: (@Sendable (CVPixelBuffer) -> Void)? {
        get { sessionLock.lock(); defer { sessionLock.unlock() }; return _onFrame }
        set { sessionLock.lock(); _onFrame = newValue; sessionLock.unlock() }
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
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw CameraError.deviceNotAvailable
        }
        
        try? device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
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
        print("Camera started at 30fps (VGA)")
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
        
        Task { @MainActor in
             self.currentFrame = CIImage(cvPixelBuffer: pixelBuffer)
        }
    }
}

public enum CameraError: Error {
    case permissionDenied
    case deviceNotAvailable
}
