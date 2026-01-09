import Foundation
import Combine

@MainActor
class IntentTrigger: ObservableObject {
    enum State {
        case idle
        case listening
        case processing
        case resolved
    }
    
    @Published var state: State = .idle
    @Published var capturedGazePoint: CGPoint = .zero
    @Published var capturedTranscript = ""
    
    private var gazeStabilityBuffer: [CGPoint] = []
    private let stabilityThreshold: CGFloat = 50
    private let stabilityWindowSize = 10
    
    var onTrigger: ((CGPoint, String) -> Void)?
    
    func updateGaze(_ point: CGPoint) {
        gazeStabilityBuffer.append(point)
        if gazeStabilityBuffer.count > stabilityWindowSize {
            gazeStabilityBuffer.removeFirst()
        }
    }
    
    func voiceStarted() {
        guard state == .idle else { return }
        state = .listening
        capturedGazePoint = computeStableGaze()
    }
    
    func voiceEnded(transcript: String) {
        guard state == .listening else { return }
        capturedTranscript = transcript
        
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else {
            state = .idle
            return
        }
        
        state = .processing
        onTrigger?(capturedGazePoint, capturedTranscript)
    }
    
    func resolved() {
        state = .resolved
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.state = .idle
        }
    }
    
    func reset() {
        state = .idle
        capturedTranscript = ""
    }
    
    private func computeStableGaze() -> CGPoint {
        guard !gazeStabilityBuffer.isEmpty else { return .zero }
        
        let sum = gazeStabilityBuffer.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        
        return CGPoint(
            x: sum.x / CGFloat(gazeStabilityBuffer.count),
            y: sum.y / CGFloat(gazeStabilityBuffer.count)
        )
    }
    
    func isGazeStable() -> Bool {
        guard gazeStabilityBuffer.count >= stabilityWindowSize else { return false }
        
        let center = computeStableGaze()
        let maxDeviation = gazeStabilityBuffer.map { point in
            sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2))
        }.max() ?? 0
        
        return maxDeviation < stabilityThreshold
    }
}
