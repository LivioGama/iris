import Foundation
import AppKit
import Combine
import IRISCore
import IRISVision

/// Simulated gaze provider that tracks mouse cursor position
/// Useful for testing without hardware gaze eye tracker
@MainActor
public class SimulatedGazeProvider: NSObject, GazeProvider, ObservableObject {
    @Published public var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @Published public var isTracking = false
    @Published public var debugInfo: String = "Simulation: Ready"
    @Published public var detectedElement: DetectedElement?
    
    public var gazePointPublisher: AnyPublisher<CGPoint, Never> {
        $gazePoint.eraseToAnyPublisher()
    }
    
    public var onRealTimeDetection: ((DetectedElement) -> Void)?
    
    public var currentScreen: NSScreen?
    
    private var timer: Timer?
    private let accessibilityDetector = AccessibilityDetector()
    private var lastDetectionTime: Date?
    private let detectionInterval: TimeInterval = 0.1
    private var lastPublishedElementSnapshot: ElementSnapshot?
    
    private struct ElementSnapshot: Equatable {
        let label: String
        let typeName: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }
    
    public override init() {
        super.init()
        if let screen = NSScreen.main {
            gazePoint = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
            currentScreen = screen
        }
    }
    
    public func start() {
        guard timer == nil else { return }
        isTracking = true
        debugInfo = "Simulation: Tracking mouse"
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateGazeFromMouse()
            }
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        isTracking = false
        debugInfo = "Simulation: Stopped"
    }
    
    public func setTrackingEnabled(_ enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }
    
    private func updateGazeFromMouse() {
        let mouseLocation = NSEvent.mouseLocation
        gazePoint = mouseLocation
        currentScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
        
        // Update debug info
        debugInfo = "Simulation: Mouse at (\(Int(mouseLocation.x)), \(Int(mouseLocation.y)))"
        
        // Perform real-time detection at current gaze point
        performDetection(at: mouseLocation)
    }
    
    private func performDetection(at point: CGPoint) {
        let now = Date()
        if let lastTime = lastDetectionTime, now.timeIntervalSince(lastTime) < detectionInterval {
            return
        }
        lastDetectionTime = now
        
        // Run detection asynchronously to not block UI thread
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let isEnabled = self.accessibilityDetector.isAccessibilityEnabled()
            if isEnabled {
                let element = self.accessibilityDetector.detectElementFast(at: point) 
                    ?? self.accessibilityDetector.detectWindow(at: point)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    let snapshot = Self.makeElementSnapshot(from: element)
                    let changed = snapshot != self.lastPublishedElementSnapshot
                    if changed {
                        self.detectedElement = element
                        self.lastPublishedElementSnapshot = snapshot
                        if let element = element {
                            self.onRealTimeDetection?(element)
                            if SimulationConfig.verboseSimulationLogging {
                                print("🎯 [SIM] Detected: \(element.label)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private static func makeElementSnapshot(from element: DetectedElement?) -> ElementSnapshot? {
        guard let element = element else { return nil }
        let bounds = element.bounds.standardized
        return ElementSnapshot(
            label: element.label,
            typeName: String(describing: element.type),
            x: Int(bounds.origin.x.rounded()),
            y: Int(bounds.origin.y.rounded()),
            width: Int(bounds.width.rounded()),
            height: Int(bounds.height.rounded())
        )
    }
}
