import Foundation
import AppKit
import Combine
import Atomics
import IRISCore
import IRISVision

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
    public var isTrackingEnabled: Bool = true

    public var onHoverDetected: ((CGPoint) -> Void)?
    public var onGazeUpdate: ((CGPoint) -> Void)?
    public var onRealTimeDetection: ((DetectedElement) -> Void)?
    public var onBlinkDetected: ((CGPoint, DetectedElement?) -> Void)?

    // Lock-free atomics for target position (updated from Python thread)
    // Using UInt64 bit pattern since Double isn't AtomicValue
    private let targetXBits = ManagedAtomic<UInt64>(960.0.bitPattern)
    private let targetYBits = ManagedAtomic<UInt64>(540.0.bitPattern)
    private var displayPoint: CGPoint = CGPoint(x: 960, y: 540)

    private let springStiffness: CGFloat = 0.35 // Matched to original for smoothness

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

    // Kalman filter for predictive smoothing
    private var kalmanFilter = KalmanFilter()

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
        setupProcessManager()
        Task { @MainActor in
            self.startAnimationTimer()
        }
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
        // Lock-free atomic reads (no contention)
        let rawTarget = CGPoint(
            x: Double(bitPattern: targetXBits.load(ordering: .relaxed)),
            y: Double(bitPattern: targetYBits.load(ordering: .relaxed))
        )

        // Kalman filter prediction (reduces perceived lag by 5-10ms)
        let predictedTarget = kalmanFilter.update(measurement: rawTarget)

        // Spring smoothing on predicted value
        var display = displayPoint
        display.x += (predictedTarget.x - display.x) * springStiffness
        display.y += (predictedTarget.y - display.y) * springStiffness
        displayPoint = display

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
        try? "🎯 GazeEstimator.start() called".appendLine(to: "/tmp/iris_startup.log")

        guard !processManager.isRunning else {
            try? "⚠️ Process manager already running".appendLine(to: "/tmp/iris_startup.log")
            return
        }

        // Log environment info
        let envInfo = IRISCore.PathResolver.getEnvironmentInfo()
        for (key, value) in envInfo {
            try? "\(key): \(value)".appendLine(to: "/tmp/iris_startup.log")
        }

        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screenWidth = Int(screen.width)
        let screenHeight = Int(screen.height)

        try? "📐 Screen: \(screenWidth)x\(screenHeight)".appendLine(to: "/tmp/iris_startup.log")

        let arguments = [
            "--eye", dominantEye.rawValue,
            String(screenWidth),
            String(screenHeight)
        ]

        try? "🐍 Starting Python with args: \(arguments)".appendLine(to: "/tmp/iris_startup.log")

        do {
            try processManager.start(arguments: arguments)
            try? "✅ Process manager started".appendLine(to: "/tmp/iris_startup.log")
        } catch {
            let errMsg = "❌ GazeEstimator failed: \(error.localizedDescription)"
            try? errMsg.appendLine(to: "/tmp/iris_startup.log")
            Task { @MainActor in
                self.debugInfo = "Failed: \(error.localizedDescription)"
            }
        }
    }

    private func parseOutput(_ data: Data) {
        var offset = 0

        while offset < data.count {
            // Try to parse binary protocol first
            if offset + 17 <= data.count {
                let typeOffset = data.startIndex + offset
                let type = data[typeOffset]

                // Binary protocol types: 1=gaze, 2=blink, 3=status, 4=calibrate
                if type >= 1 && type <= 4 {
                    // Extract x and y coordinates (network byte order = big endian)
                    let xData = data.subdata(in: (typeOffset + 1)..<(typeOffset + 9))
                    let yData = data.subdata(in: (typeOffset + 9)..<(typeOffset + 17))

                    // Load as UInt64, swap bytes, then convert to Double
                    let xBits = xData.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
                    let yBits = yData.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
                    let x = Double(bitPattern: xBits)
                    let y = Double(bitPattern: yBits)

                    switch type {
                    case 1: // TYPE_GAZE
                        // Lock-free atomic stores (from Python thread)
                        targetXBits.store(xBits, ordering: .relaxed)
                        targetYBits.store(yBits, ordering: .relaxed)

                    case 2: // TYPE_BLINK
                        let blinkPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
                        print("👁️ BLINK DETECTED at (\(x), \(y))")
                        Task { @MainActor in
                            print("👁️ Calling onBlinkDetected handler")
                            self.onBlinkDetected?(blinkPoint, self.detectedElement)
                        }

                    default:
                        break
                    }

                    offset += 17
                    continue
                }
            }

            // Fallback to JSON parsing for status messages
            // Find next newline for JSON message boundary
            let remainingData = data.subdata(in: (data.startIndex + offset)..<data.endIndex)
            guard let str = String(data: remainingData, encoding: .utf8) else { break }

            let lines = str.components(separatedBy: "\n")
            guard let line = lines.first, !line.isEmpty else { break }

            // Parse JSON status messages
            if let jsonData = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                if let status = json["status"] as? String {
                    print("📊 Status message: \(status)")
                    Task { @MainActor in
                        if status.starts(with: "calibrate_") {
                            let corner = String(status.dropFirst(10))
                            self.calibrationCorner = CalibrationCorner(rawValue: corner) ?? .none
                            self.debugInfo = "Look at \(corner)"
                        } else if status == "calibrated" {
                            self.calibrationCorner = .done
                            self.debugInfo = "Ready"
                            self.isTracking = true
                        } else if status.contains("blink") || status.contains("trigger") {
                            print("👁️ Blink status: \(status)")
                            self.debugInfo = status
                        } else {
                            self.debugInfo = status
                        }
                    }
                }
            }

            // Move past this JSON line
            offset += line.utf8.count + 1 // +1 for newline
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

    deinit {
        timer?.invalidate()
        processManager.stop()
    }
}
