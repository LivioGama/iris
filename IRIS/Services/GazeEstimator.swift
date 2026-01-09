import Vision
import CoreImage
import AppKit

@MainActor
class GazeEstimator: ObservableObject {
    @Published var gazePoint: CGPoint = .zero
    @Published var isCalibrated = false
    
    private var calibrationData: CalibrationData?
    private var smoothingBuffer: [CGPoint] = []
    private let smoothingWindowSize = 5
    
    private let faceDetectionRequest: VNDetectFaceLandmarksRequest = {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        return request
    }()
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        
        do {
            try handler.perform([faceDetectionRequest])
            
            guard let results = faceDetectionRequest.results,
                  let face = results.first,
                  let landmarks = face.landmarks else { return }
            
            let gazeVector = calculateGazeVector(from: landmarks, in: face.boundingBox)
            let screenPoint = mapToScreen(gazeVector)
            
            Task { @MainActor in
                self.updateGazePoint(screenPoint)
            }
        } catch {}
    }
    
    private func calculateGazeVector(from landmarks: VNFaceLandmarks2D, in boundingBox: CGRect) -> CGPoint {
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye,
              let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            return .zero
        }
        
        let leftEyeCenter = averagePoint(leftEye.normalizedPoints)
        let rightEyeCenter = averagePoint(rightEye.normalizedPoints)
        let leftPupilCenter = averagePoint(leftPupil.normalizedPoints)
        let rightPupilCenter = averagePoint(rightPupil.normalizedPoints)
        
        let leftOffset = CGPoint(
            x: leftPupilCenter.x - leftEyeCenter.x,
            y: leftPupilCenter.y - leftEyeCenter.y
        )
        let rightOffset = CGPoint(
            x: rightPupilCenter.x - rightEyeCenter.x,
            y: rightPupilCenter.y - rightEyeCenter.y
        )
        
        return CGPoint(
            x: (leftOffset.x + rightOffset.x) / 2,
            y: (leftOffset.y + rightOffset.y) / 2
        )
    }
    
    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
    
    private func mapToScreen(_ gazeVector: CGPoint) -> CGPoint {
        guard let screen = NSScreen.main else { return .zero }
        let screenSize = screen.frame.size
        
        let sensitivity: CGFloat = 15.0
        let centerX = screenSize.width / 2
        let centerY = screenSize.height / 2
        
        return CGPoint(
            x: centerX + gazeVector.x * screenSize.width * sensitivity,
            y: centerY - gazeVector.y * screenSize.height * sensitivity
        )
    }
    
    private func updateGazePoint(_ point: CGPoint) {
        smoothingBuffer.append(point)
        if smoothingBuffer.count > smoothingWindowSize {
            smoothingBuffer.removeFirst()
        }
        
        let smoothed = smoothingBuffer.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        gazePoint = CGPoint(
            x: smoothed.x / CGFloat(smoothingBuffer.count),
            y: smoothed.y / CGFloat(smoothingBuffer.count)
        )
    }
    
    func startCalibration() {
        calibrationData = CalibrationData()
    }
    
    func recordCalibrationPoint(screenPoint: CGPoint, gazeVector: CGPoint) {
        calibrationData?.points.append((screenPoint, gazeVector))
        if calibrationData?.points.count == 4 {
            isCalibrated = true
        }
    }
}

struct CalibrationData {
    var points: [(screen: CGPoint, gaze: CGPoint)] = []
}
