import Foundation
import AppKit
import Combine
import IRISCore
import IRISVision

public enum CalibrationCorner: String {
    case none, topLeft, topRight, bottomLeft, bottomRight, center, done
}

public enum DominantEye: String {
    case left, right
}

public class GazeEstimator: ObservableObject {
    @MainActor @Published public var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @MainActor @Published public var isTracking = false
    @MainActor @Published public var debugInfo: String = "Starting..."
    @MainActor @Published public var calibrationCorner: CalibrationCorner = .none
    @MainActor @Published public var detectedElement: DetectedElement?

    public var dominantEye: DominantEye = .left
    public var isTrackingEnabled: Bool = true

    public var onHoverDetected: ((CGPoint) -> Void)?
    public var onGazeUpdate: ((CGPoint) -> Void)?
    public var onRealTimeDetection: ((DetectedElement) -> Void)?
    public var onBlinkDetected: ((CGPoint, DetectedElement?) -> Void)?

    private let lock = NSLock()
    private var targetPoint: CGPoint = CGPoint(x: 960, y: 540)
    private var displayPoint: CGPoint = CGPoint(x: 960, y: 540)

    private let springStiffness: CGFloat = 0.35 // Increased from 0.15 for snappier visual response

    private let processManager = PythonProcessManager(scriptName: "eye_tracker.py")
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
            targetPoint = center
            displayPoint = center
        }
        setupProcessManager()
        startAnimationTimer()
    }

    private func setupProcessManager() {
        processManager.onOutput = { [weak self] data in
            self?.parseOutput(data)
        }

        processManager.onStateChange = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .starting:
                    self?.debugInfo = "Starting..."
                case .running:
                    self?.debugInfo = "Calibrating..."
                case .recovering:
                    self?.debugInfo = "Recovering..."
                    self?.isTracking = false
                case .failed(let error):
                    self?.debugInfo = "Error: \(error.localizedDescription)"
                    self?.isTracking = false
                case .idle:
                    self?.debugInfo = "Stopped"
                    self?.isTracking = false
                }
            }
        }

        processManager.onError = { error in
            print("❌ GazeEstimator: Process error - \(error.localizedDescription)")
        }

        processManager.onRecovery = { [weak self] in
            Task { @MainActor in
                self?.debugInfo = "Attempting recovery..."
            }
        }
    }

    private func startAnimationTimer() {
        updateAnimationTimer()
    }

    private func updateAnimationTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Invalidate existing timer
            self.timer?.invalidate()

            // Determine frame rate based on current mode
            let frameInterval = self.currentFrameRateMode == .highPerformance ? self.highPerformanceFPS : self.lowPowerFPS

            // Create new timer with adaptive frame rate
            self.timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
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
            updateAnimationTimer()
        }
    }

    public func setHeavyProcessing(_ active: Bool) {
        heavyProcessingActive = active
    }

    private func animateToTarget() {
        lock.lock()
        let target = targetPoint
        var display = displayPoint
        lock.unlock()

        display.x += (target.x - display.x) * springStiffness
        display.y += (target.y - display.y) * springStiffness

        lock.lock()
        displayPoint = display
        lock.unlock()

        Task { @MainActor in
            self.gazePoint = display
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
            // Try to detect specific element first
            var element = accessibilityDetector.detectElementFast(at: point)

            // If no specific element found, fall back to window detection
            if element == nil {
                element = accessibilityDetector.detectWindow(at: point)
            }

            if let element = element {
                Task { @MainActor in
                    self.detectedElement = element
                    self.onRealTimeDetection?(element)
                    print("✓ Detected: \(element.label) at \(element.bounds)")
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
        guard !processManager.isRunning else { return }

        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screenWidth = Int(screen.width)
        let screenHeight = Int(screen.height)

        let arguments = [
            "--eye", dominantEye.rawValue,
            String(screenWidth),
            String(screenHeight)
        ]

        do {
            try processManager.start(arguments: arguments)
        } catch {
            Task { @MainActor in
                self.debugInfo = "Failed: \(error.localizedDescription)"
            }
        }
    }

    private func parseOutput(_ data: Data) {
        guard let str = String(data: data, encoding: .utf8) else { return }
        let lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }

        for line in lines {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            // Handle blink event
            if let event = json["event"] as? String, event == "blink" {
                if let x = json["x"] as? Double, let y = json["y"] as? Double {
                    let blinkPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
                    Task { @MainActor in
                        self.onBlinkDetected?(blinkPoint, self.detectedElement)
                    }
                }
                continue
            }

            if let status = json["status"] as? String {
                Task { @MainActor in
                    if status.starts(with: "calibrate_") {
                        let corner = String(status.dropFirst(10))
                        self.calibrationCorner = CalibrationCorner(rawValue: corner) ?? .none
                        self.debugInfo = "Look at \(corner)"
                    } else if status == "calibrated" {
                        self.calibrationCorner = .done
                        self.debugInfo = "Ready"
                        self.isTracking = true
                    } else {
                        self.debugInfo = status
                    }
                }
                continue
            }

            guard let x = json["x"] as? Double, let y = json["y"] as? Double else { continue }

            lock.lock()
            targetPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
            lock.unlock()
        }
    }

    public func stop() {
        processManager.stop()
        Task { @MainActor in
            self.isTracking = false
            self.debugInfo = "Stopped"
        }
    }

    public func restart() {
        processManager.restart()
    }

    public func processFrame(_ pixelBuffer: CVPixelBuffer) {
    }

    deinit {
        timer?.invalidate()
        processManager.stop()
    }
}
