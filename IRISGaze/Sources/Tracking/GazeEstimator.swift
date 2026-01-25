import Foundation
import AppKit
import Combine
import Atomics
import IRISCore
import IRISVision
import CIrisGaze

extension String {
    func appendLine(to path: String) throws {
        let line = self + "\n"
        if let fileHandle = FileHandle(forWritingAtPath: path) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(line.data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            try line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

public enum CalibrationCorner: String {
    case none, topLeft, topRight, bottomLeft, bottomRight, center, done
}

public enum DominantEye: String {
    case left, right
}

@MainActor
public class GazeEstimator: ObservableObject {
    @MainActor @Published public var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @MainActor @Published public var isTracking = false
    @MainActor @Published public var debugInfo: String = "Starting..."
    @MainActor @Published public var calibrationCorner: CalibrationCorner = .none
    @MainActor @Published public var detectedElement: DetectedElement?


    public var dominantEye: DominantEye = .left
    @MainActor @Published public var isTrackingEnabled: Bool = true
    public var currentScreen: NSScreen? = nil // Track which screen user is looking at
    public var shouldScaleForExternalScreen: ((CGPoint) -> Bool)? = nil // Callback to determine if we should scale

    public var onHoverDetected: ((CGPoint) -> Void)?
    public var onGazeUpdate: ((CGPoint) -> Void)?
    public var onRealTimeDetection: ((DetectedElement) -> Void)?
    public var onBlinkDetected: ((CGPoint, DetectedElement?) -> Void)?
    public var onBlinkDetectedWithEye: ((CGPoint, DetectedElement?, RustGazeTracker.BlinkEye) -> Void)?

    // Lock-free atomics for target position (updated from Python thread)
    // Using UInt64 bit pattern since Double isn't AtomicValue
    private let targetXBits = ManagedAtomic<UInt64>(960.0.bitPattern)
    private let targetYBits = ManagedAtomic<UInt64>(540.0.bitPattern)
    private var displayPoint: CGPoint = CGPoint(x: 960, y: 540)

    private let springStiffness: CGFloat = 0.55 // Increased from 0.35 for lower latency
    private let calibrationResolution = CGSize(width: 3840, height: 1600)

    // Rust backend for gaze tracking
    private let rustTracker = RustGazeTracker()

    private var timer: Timer?

    // Adaptive Frame Rate System
    private enum FrameRateMode {
        case highPerformance  // 60 FPS - simple UI, no heavy processing
        case lowPower        // 15 FPS - heavy processing active
    }
    private var currentFrameRateMode: FrameRateMode = .highPerformance
    private let highPerformanceFPS: TimeInterval = 1.0 / 60.0
    private let lowPowerFPS: TimeInterval = 1.0 / 15.0
    private var heavyProcessingActive: Bool = false {
        didSet {
            updateFrameRateMode()
        }
    }

    private var lastRealTimeDetectionTime: Date?
    private let realTimeDetectionInterval: TimeInterval = 1.0 / 30.0 // Maintain 30 FPS element detection
    private let accessibilityDetector = AccessibilityDetector()
    private let computerVisionDetector = ComputerVisionDetector()

    // Kalman filter for predictive smoothing
    private var kalmanFilter = KalmanFilter()

    // Dead Zone Filter - suppresses tiny unwanted movements
    private struct DeadZoneFilter {
        var lastStablePosition: CGPoint?
        let deadZoneRadius: CGFloat = 15.0  // Ignore movements smaller than this
        let escapeVelocity: CGFloat = 50.0  // Fast movements break out immediately
        
        mutating func filter(newPosition: CGPoint, deltaTime: TimeInterval) -> CGPoint {
            guard let lastPos = lastStablePosition else {
                lastStablePosition = newPosition
                return newPosition
            }
            
            let dx = newPosition.x - lastPos.x
            let dy = newPosition.y - lastPos.y
            let distance = hypot(dx, dy)
            
            // Calculate velocity (pixels per second)
            let velocity = deltaTime > 0 ? distance / CGFloat(deltaTime) : 0
            
            // Fast movements bypass dead zone (intentional saccades)
            if velocity > escapeVelocity {
                lastStablePosition = newPosition
                return newPosition
            }
            
            // Small movements stay in dead zone (micro-jitter suppression)
            if distance < deadZoneRadius {
                return lastPos  // Hold position, resist tiny movements
            }
            
            // Medium movements: gradual transition out of dead zone
            // This creates smooth acceleration when breaking out
            let transitionFactor = min(1.0, (distance - deadZoneRadius) / deadZoneRadius)
            let filtered = CGPoint(
                x: lastPos.x + dx * transitionFactor,
                y: lastPos.y + dy * transitionFactor
            )
            
            lastStablePosition = filtered
            return filtered
        }
        
        mutating func reset() {
            lastStablePosition = nil
        }
    }
    
    private var deadZoneFilter = DeadZoneFilter()

    // Temporal Stability Filter (replaces buffer-based approach)
    private struct TemporalStability {
        var lastPosition: CGPoint?
        var stabilityStartTime: Date?
        var movementHistory: [(time: Date, distance: CGFloat)] = []
        let maxHistorySize = 10
        let stabilityRadius: CGFloat = 30.0
        let requiredStableDuration: TimeInterval = 0.15

        mutating func update(newPosition: CGPoint) -> Bool {
            let now = Date()

            guard let lastPos = lastPosition else {
                lastPosition = newPosition
                stabilityStartTime = now
                return false
            }

            let distance = hypot(newPosition.x - lastPos.x, newPosition.y - lastPos.y)

            // Add to movement history
            movementHistory.append((time: now, distance: distance))
            if movementHistory.count > maxHistorySize {
                movementHistory.removeFirst()
            }

            // Check if movement is within stability radius
            if distance <= stabilityRadius {
                // Stable position - check duration
                if stabilityStartTime == nil {
                    stabilityStartTime = now
                }

                if let startTime = stabilityStartTime,
                   now.timeIntervalSince(startTime) >= requiredStableDuration {
                    return true // Hover detected
                }
            } else {
                // Movement detected - reset stability
                stabilityStartTime = nil
            }

            lastPosition = newPosition
            return false
        }

        mutating func reset() {
            stabilityStartTime = nil
        }

        func getStablePosition() -> CGPoint? {
            return lastPosition
        }
    }

    private var temporalStability = TemporalStability()
    private var analysisInProgress = false

    public init() {
        if let screen = NSScreen.main {
            let center = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
            targetXBits.store(UInt64(Double(center.x).bitPattern), ordering: .relaxed)
            targetYBits.store(UInt64(Double(center.y).bitPattern), ordering: .relaxed)
            displayPoint = center
        }

        setupRustTracker()

        Task { @MainActor in
            self.startAnimationTimer()
        }
    }

    private func setupRustTracker() {
        rustTracker.onGaze = { [weak self] x, y in
            guard let self = self else { return }
            self.targetXBits.store(UInt64(x.bitPattern), ordering: .relaxed)
            self.targetYBits.store(UInt64(y.bitPattern), ordering: .relaxed)
        }

        rustTracker.onBlink = { [weak self] x, y, blinkEye in
            guard let self = self else { return }
            let blinkPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
            print("👁️ BLINK DETECTED (Rust) at (\(x), \(y)) eye=\(blinkEye)")
            Task { @MainActor in
                self.onBlinkDetected?(blinkPoint, self.detectedElement)
                self.onBlinkDetectedWithEye?(blinkPoint, self.detectedElement, blinkEye)
            }
        }

        rustTracker.onStateChange = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .starting:
                    self?.debugInfo = "Starting (Rust)..."
                case .running:
                    self?.debugInfo = "Ready (Rust)"
                    self?.isTracking = true
                    self?.calibrationCorner = .done
                case .paused:
                    self?.debugInfo = "Paused"
                case .failed(let error):
                    self?.debugInfo = "Error: \(error.localizedDescription)"
                    self?.isTracking = false
                case .idle:
                    self?.debugInfo = "Stopped"
                    self?.isTracking = false
                }
            }
        }
    }

    @MainActor
    private func startAnimationTimer() {
        updateAnimationTimer()
    }

    @MainActor
    private func updateAnimationTimer() {
        // Invalidate existing timer
        timer?.invalidate()

        // Always use 60 FPS for smooth gaze tracking - runs on main RunLoop
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.animateToTarget()
            }
        }
    }

    private func updateFrameRateMode() {
        let newMode: FrameRateMode = heavyProcessingActive ? .lowPower : .highPerformance

        if newMode != currentFrameRateMode {
            currentFrameRateMode = newMode
            let fps = newMode == .highPerformance ? 60 : 15
            print("📊 Frame rate mode changed to \(fps) FPS (\(newMode == .highPerformance ? "high performance" : "low power"))")
            Task { @MainActor in
                self.updateAnimationTimer()
            }
        }
    }

    public func setHeavyProcessing(_ active: Bool) {
        heavyProcessingActive = active
    }

    private func animateToTarget() {
        guard isTrackingEnabled else { return }

        // Lock-free atomic reads (no contention)
        let rawTarget = CGPoint(
            x: Double(bitPattern: targetXBits.load(ordering: .relaxed)),
            y: Double(bitPattern: targetYBits.load(ordering: .relaxed))
        )

        // Kalman filter prediction (reduces perceived lag by 5-10ms)
        let predictedTarget = kalmanFilter.update(measurement: rawTarget)

        // Dead zone filter (suppresses micro-jitter and unwanted tiny movements)
        let deltaTime = 1.0 / 60.0  // 60 FPS
        let filteredTarget = deadZoneFilter.filter(newPosition: predictedTarget, deltaTime: deltaTime)

        // Spring smoothing on filtered value
        var display = displayPoint
        display.x += (filteredTarget.x - display.x) * springStiffness
        display.y += (filteredTarget.y - display.y) * springStiffness
        displayPoint = display

        Task { @MainActor in
            self.gazePoint = display
            // Update current screen based on gaze point
            self.currentScreen = NSScreen.screens.first(where: { $0.frame.contains(display) })
            self.updateHoverDetection(with: display)
            self.triggerRealTimeDetection(at: display)
            self.triggerGazeUpdate(with: display)
        }
    }

    private func triggerRealTimeDetection(at point: CGPoint) {
        guard isTrackingEnabled else { return }

        let now = Date()
        if let lastTime = lastRealTimeDetectionTime, now.timeIntervalSince(lastTime) < realTimeDetectionInterval {
            return
        }
        lastRealTimeDetectionTime = now

        if accessibilityDetector.isAccessibilityEnabled() {
            var detectionPoint = point

            if let screen = currentScreen ?? NSScreen.main {
                let (convertedPoint, logMsg) = accessibilityCoordinates(for: point, on: screen)
                detectionPoint = convertedPoint
                print(logMsg)
                try? logMsg.appendLine(to: "/tmp/iris_detection.log")
            }

            // Try to detect specific element first
            var element = accessibilityDetector.detectElementFast(at: detectionPoint)

            // If no specific element found, fall back to window detection
            if element == nil {
                element = accessibilityDetector.detectWindow(at: detectionPoint)
            }

            if let element = element {
                Task { @MainActor in
                    self.detectedElement = element
                    self.onRealTimeDetection?(element)
                    let detectMsg = "✓ Detected: \(element.label) at \(element.bounds)"
                    print(detectMsg)
                    try? detectMsg.appendLine(to: "/tmp/iris_detection.log")
                }
            } else {
                Task { @MainActor in
                    self.detectedElement = nil
                }
            }
        } else {
            Task { @MainActor in
                self.debugInfo = "Accessibility not enabled!"
            }
        }
    }

    private func accessibilityCoordinates(for point: CGPoint, on screen: NSScreen) -> (CGPoint, String) {
        var scaledPoint = scaledPointForScreen(point, screen: screen)

        // Apply camera offset compensation for external screen (3840x1600)
        // Camera is positioned below the screen, so gaze coordinates need offset
        // Apply BEFORE clamping so we can detect elements at the top
        let isExternalScreen = screen.frame.width == 3840 && screen.frame.height == 1600
        if isExternalScreen {
            scaledPoint.y += 700
        }

        let clampedX = min(max(scaledPoint.x, 0), screen.frame.width)
        // For external screen, allow coordinates beyond screen height to account for offset
        let maxY = isExternalScreen ? screen.frame.height + 700 : screen.frame.height
        let clampedYFromTop = min(max(scaledPoint.y, 0), maxY)

        // Convert to global AppKit coordinates
        let localX = clampedX
        let localY = screen.frame.height - clampedYFromTop  // Flip Y within screen
        let globalX = screen.frame.origin.x + localX
        let globalY = screen.frame.origin.y + localY

        // Accessibility uses global coords with Y-down from primary screen's top
        // Primary screen is at origin (0,0), NOT NSScreen.main (which is the focused screen)
        let primaryScreen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens[0]
        let accessibilityX = globalX
        let accessibilityY = primaryScreen.frame.maxY - globalY

        let accessibilityPoint = CGPoint(x: accessibilityX, y: accessibilityY)
        let logMsg = "🔍 SCREEN(\(Int(screen.frame.width))x\(Int(screen.frame.height))): Py(\(Int(point.x)),\(Int(point.y))) → Local(\(Int(localX)),\(Int(localY))) → Global(\(Int(globalX)),\(Int(globalY))) → Acc(\(Int(accessibilityPoint.x)),\(Int(accessibilityPoint.y))) [primary:\(Int(primaryScreen.frame.origin.x)),\(Int(primaryScreen.frame.maxY))]"
        return (accessibilityPoint, logMsg)
    }

    private func scaledPointForScreen(_ point: CGPoint, screen: NSScreen) -> CGPoint {
        var scaledPoint = point

        // Scale if needed
        if screen.frame.size != calibrationResolution {
            let scaleX = screen.frame.width / calibrationResolution.width
            let scaleY = screen.frame.height / calibrationResolution.height
            scaledPoint = CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }

        // NOTE: Camera offset is NOT applied here - it's applied in accessibilityCoordinates
        // after clamping to avoid cutting off the top of the screen

        return scaledPoint
    }

    private func triggerGazeUpdate(with point: CGPoint) {
        onGazeUpdate?(point)
    }

    private func updateHoverDetection(with point: CGPoint) {
        guard isTrackingEnabled else {
            temporalStability.reset()
            return
        }

        // Use temporal stability filter
        let isHovering = temporalStability.update(newPosition: point)

        if isHovering && !analysisInProgress {
            // Hover detected - trigger analysis
            analysisInProgress = true
            setHeavyProcessing(true) // Switch to low power mode during analysis

            guard let stablePoint = temporalStability.getStablePosition() else { return }

            Task { @MainActor in
                if let element = self.detectedElement {
                    let typeStr = String(describing: element.type)
                    let size = "\(Int(element.bounds.width))×\(Int(element.bounds.height))"
                    self.debugInfo = "Hover: \(element.label) | \(typeStr) | \(size)"
                } else {
                    self.debugInfo = "Hover detected! Analyzing..."
                }
            }

            onHoverDetected?(stablePoint)

            // Reset temporal stability after detection
            temporalStability.reset()

            // Reset analysis flag and restore high performance mode after delay
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                analysisInProgress = false
                setHeavyProcessing(false) // Restore high performance mode
            }
        }
    }

    public func start() {
        try? "🎯 GazeEstimator.start() called".appendLine(to: "/tmp/iris_startup.log")

        // Use the largest screen resolution for calibration (usually the external monitor)
        // This ensures eye tracking covers the full range of all displays
        let largestScreen = NSScreen.screens.max(by: { $0.frame.width < $1.frame.width }) ?? NSScreen.main
        let screen = largestScreen?.frame ?? CGRect(x: 0, y: 0, width: 3840, height: 1600)
        let screenWidth = Int(screen.width)
        let screenHeight = Int(screen.height)

        try? "📐 Screen: \(screenWidth)x\(screenHeight)".appendLine(to: "/tmp/iris_startup.log")

        guard !rustTracker.isRunning else {
            try? "⚠️ Rust tracker already running".appendLine(to: "/tmp/iris_startup.log")
            return
        }

        try? "🦀 Starting Rust backend".appendLine(to: "/tmp/iris_startup.log")

        do {
            try rustTracker.start(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                dominantEye: dominantEye.rawValue
            )
            try? "✅ Rust tracker started".appendLine(to: "/tmp/iris_startup.log")
        } catch {
            let errMsg = "❌ Rust tracker failed: \(error.localizedDescription)"
            try? errMsg.appendLine(to: "/tmp/iris_startup.log")
            Task { @MainActor in
                self.debugInfo = "Failed: \(error.localizedDescription)"
            }
        }
    }

    public func setTrackingEnabled(_ enabled: Bool) {
        guard isTrackingEnabled != enabled else { return }
        isTrackingEnabled = enabled

        if !enabled {
            temporalStability.reset()
            self.detectedElement = nil
            self.debugInfo = "Tracking disabled"
        } else {
            self.debugInfo = "Tracking enabled"
        }
    }

    public func stop() {
        rustTracker.stop()
        Task { @MainActor in
            self.isTracking = false
            self.debugInfo = "Stopped"
        }
    }

    public func restart() {
        rustTracker.stop()
        // Small delay before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start()
        }
    }

    deinit {
        // Note: Timer and tracker cleanup is handled by their own deinit methods
        // We cannot access MainActor-isolated properties from deinit
    }
}
