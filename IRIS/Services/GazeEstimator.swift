import Foundation
import AppKit
import Combine

enum CalibrationCorner: String {
    case none, topLeft, topRight, bottomLeft, bottomRight, center, done
}

enum DominantEye: String {
    case left, right
}

class GazeEstimator: ObservableObject {
    @MainActor @Published var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @MainActor @Published var isTracking = false
    @MainActor @Published var debugInfo: String = "Starting..."
    @MainActor @Published var calibrationCorner: CalibrationCorner = .none
    @MainActor @Published var detectedElement: DetectedElement?

    var dominantEye: DominantEye = .left
    var isTrackingEnabled: Bool = true

    var onHoverDetected: ((CGPoint) -> Void)?
    var onGazeUpdate: ((CGPoint) -> Void)?
    var onRealTimeDetection: ((DetectedElement) -> Void)?
    var onBlinkDetected: ((CGPoint, DetectedElement?) -> Void)?

    private let lock = NSLock()
    private var targetPoint: CGPoint = CGPoint(x: 960, y: 540)
    private var displayPoint: CGPoint = CGPoint(x: 960, y: 540)

    private let springStiffness: CGFloat = 0.35 // Increased from 0.15 for snappier visual response

    private var process: Process?
    private var timer: Timer?
    private let processQueue = DispatchQueue(label: "com.iris.python", qos: .userInteractive)

    private var lastRealTimeDetectionTime: Date?
    private let realTimeDetectionInterval: TimeInterval = 1.0 / 30.0 // Increased from 15 FPS to 30 FPS for smoother detection
    private let accessibilityDetector = AccessibilityDetector()
    private let computerVisionDetector = ComputerVisionDetector()

    private var hoverDetectionBuffer: [CGPoint] = []
    private let hoverThreshold: CGFloat = 30.0
    private let hoverDuration: TimeInterval = 0.15 // Reduced from 0.5 to 0.15 seconds for instant feel
    private let stabilityWindowSize = 5 // Reduced from 10 to 5 for faster response
    private let debounceInterval: TimeInterval = 0.05 // Reduced from 0.1 to 0.05 for faster checks
    private var lastHoverCheckTime: Date?
    private var hoverStartTime: Date?
    private var analysisInProgress = false

    init() {
        if let screen = NSScreen.main {
            let center = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
            targetPoint = center
            displayPoint = center
        }
        startAnimationTimer()
    }

    private func startAnimationTimer() {
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                self?.animateToTarget()
            }
        }
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
        guard isTrackingEnabled else { return }

        // Add current point to buffer
        hoverDetectionBuffer.append(point)
        if hoverDetectionBuffer.count > stabilityWindowSize {
            hoverDetectionBuffer.removeFirst()
        }

        // Debounced hover stability check
        let now = Date()
        if let lastCheck = lastHoverCheckTime, now.timeIntervalSince(lastCheck) < debounceInterval {
            return
        }
        lastHoverCheckTime = now

        guard hoverDetectionBuffer.count >= stabilityWindowSize else {
            // Clear hover state if buffer is too small
            hoverStartTime = nil
            return
        }

        // Check if gaze is stable using improved metrics
        let stabilityScore = calculateStabilityScore()

        if stabilityScore >= 0.7 { // Reduced from 80% to 70% for faster triggering
            if hoverStartTime == nil {
                // Start hover timer
                hoverStartTime = now
                Task { @MainActor in
                    if let element = self.detectedElement {
                        let typeStr = String(describing: element.type)
                        let size = "\(Int(element.bounds.width))×\(Int(element.bounds.height))"
                        self.debugInfo = "Hover: \(element.label) | \(typeStr) | \(size)"
                    } else {
                        self.debugInfo = "Hover started..."
                    }
                }
            } else if now.timeIntervalSince(hoverStartTime!) >= hoverDuration && !analysisInProgress {
                // Hover detected - trigger analysis
                analysisInProgress = true
                let stablePoint = computeStableGaze()
                Task { @MainActor in
                    self.debugInfo = "Hover detected! Analyzing..."
                }
                onHoverDetected?(stablePoint)

                // Reset hover state but keep analysis flag
                hoverStartTime = nil

                // Reset analysis flag after delay to prevent spam
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    analysisInProgress = false
                }
            }
        } else {
            // Reset hover state if stability drops
            hoverStartTime = nil
            if stabilityScore < 0.5 {
                Task { @MainActor in
                    self.debugInfo = "Gaze unstable (\(Int(stabilityScore * 100))%)"
                }
            }
        }
    }

    private func calculateStabilityScore() -> Double {
        guard hoverDetectionBuffer.count >= stabilityWindowSize else { return 0.0 }

        // Calculate centroid of all points
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0

        for point in hoverDetectionBuffer {
            totalX += point.x
            totalY += point.y
        }

        let centroid = CGPoint(
            x: totalX / CGFloat(hoverDetectionBuffer.count),
            y: totalY / CGFloat(hoverDetectionBuffer.count)
        )

        // Calculate average distance from centroid
        var totalDistance: CGFloat = 0
        for point in hoverDetectionBuffer {
            let distance = hypot(point.x - centroid.x, point.y - centroid.y)
            totalDistance += distance
        }

        let averageDistance = totalDistance / CGFloat(hoverDetectionBuffer.count)

        // Calculate variance (how spread out the points are)
        var variance: CGFloat = 0
        for point in hoverDetectionBuffer {
            let distance = hypot(point.x - centroid.x, point.y - centroid.y)
            variance += pow(distance - averageDistance, 2)
        }
        variance /= CGFloat(hoverDetectionBuffer.count)

        // Calculate standard deviation
        let standardDeviation = sqrt(variance)

        // Stability score: lower standard deviation = higher stability
        // Score ranges from 0 (unstable) to 1 (very stable)
        let maxAcceptableDeviation = hoverThreshold / 2.0 // Half the threshold
        let stabilityScore = max(0.0, min(1.0, 1.0 - (standardDeviation / maxAcceptableDeviation)))

        return stabilityScore
    }

    private func computeStableGaze() -> CGPoint {
        guard !hoverDetectionBuffer.isEmpty else { return .zero }

        let sum = hoverDetectionBuffer.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }

        return CGPoint(
            x: sum.x / CGFloat(hoverDetectionBuffer.count),
            y: sum.y / CGFloat(hoverDetectionBuffer.count)
        )
    }


    func start() {
        guard process == nil else { return }

        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        var projectDir: String
        let bundlePath = Bundle.main.bundlePath

        if bundlePath.contains("/.build/") {
            projectDir = bundlePath.components(separatedBy: "/.build/").first ?? "/Users/livio/Documents/iris2"
        } else if bundlePath.contains("/DerivedData/") {
            projectDir = "/Users/livio/Documents/iris2"
        } else if bundlePath.contains("/IRIS.app") {
            projectDir = bundlePath.components(separatedBy: "/IRIS.app").first ?? "/Users/livio/Documents/iris2"
        } else {
            projectDir = "/Users/livio/Documents/iris2"
        }

        let pythonPath = "\(projectDir)/gaze_env/bin/python3"
        let scriptPath = "\(projectDir)/eye_tracker.py"

        guard FileManager.default.fileExists(atPath: pythonPath),
              FileManager.default.fileExists(atPath: scriptPath) else {
            Task { @MainActor in
                self.debugInfo = "Not found"
            }
            return
        }

        processQueue.async { [weak self] in
            self?.launchPythonProcess(
                pythonPath: pythonPath,
                scriptPath: scriptPath,
                screenWidth: Int(screen.width),
                screenHeight: Int(screen.height)
            )
        }
    }

    private func launchPythonProcess(pythonPath: String, scriptPath: String, screenWidth: Int, screenHeight: Int) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [scriptPath, "--eye", dominantEye.rawValue, String(screenWidth), String(screenHeight)]
        proc.environment = ProcessInfo.processInfo.environment
        proc.environment?["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        process = proc

        do {
            try proc.run()
            Task { @MainActor in
                self.debugInfo = "Calibrating..."
            }
        } catch {
            Task { @MainActor in
                self.debugInfo = "Failed"
            }
            return
        }

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty else {
                self?.handleProcessEnd()
                return
            }
            self?.parseOutput(data)
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

    private func handleProcessEnd() {
        Task { @MainActor in
            self.debugInfo = "Ended"
            self.isTracking = false
        }
        process = nil
    }

    func stop() {
        process?.terminate()
        process = nil
        Task { @MainActor in
            self.isTracking = false
            self.debugInfo = "Stopped"
        }
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
    }

    deinit {
        timer?.invalidate()
        process?.terminate()
    }
}
