import Foundation
import AppKit
import Combine
import IRISCore

/// Protocol for any gaze input source (real hardware or simulated)
public protocol GazeProvider: AnyObject {
    /// Current gaze point on screen
    var gazePoint: CGPoint { get }
    
    /// Publisher for gaze point updates
    var gazePointPublisher: AnyPublisher<CGPoint, Never> { get }
    
    /// Whether gaze tracking is active
    var isTracking: Bool { get }
    
    /// Debug information about gaze tracking
    var debugInfo: String { get }
    
    /// Detected element at current gaze point
    var detectedElement: DetectedElement? { get }
    
    /// Callback when element is detected in real-time
    var onRealTimeDetection: ((DetectedElement) -> Void)? { get set }
    
    /// Start tracking gaze
    func start()
    
    /// Stop tracking gaze
    func stop()
    
    /// Set tracking enabled/disabled (pause without stopping)
    func setTrackingEnabled(_ enabled: Bool)
    
    /// Current screen being gazed at
    var currentScreen: NSScreen? { get set }
}
