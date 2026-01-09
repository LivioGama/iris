import AVFoundation
import CoreImage

@MainActor
class CameraService: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "camera.processing")
    
    @Published var currentFrame: CIImage?
    @Published var isRunning = false
    
    var onFrame: ((CVPixelBuffer) -> Void)?
    
    func start() async throws {
        guard await checkPermission() else {
            throw CameraError.permissionDenied
        }
        
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw CameraError.deviceNotAvailable
        }
        
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: processingQueue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        session.addOutput(output)
        
        captureSession = session
        videoOutput = output
        
        session.startRunning()
        isRunning = true
    }
    
    func stop() {
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
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        Task { @MainActor in
            self.onFrame?(pixelBuffer)
            self.currentFrame = CIImage(cvPixelBuffer: pixelBuffer)
        }
    }
}

enum CameraError: Error {
    case permissionDenied
    case deviceNotAvailable
}
