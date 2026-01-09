import Foundation
import AppKit
import Combine

enum CalibrationCorner: String {
    case none, topLeft, topRight, bottomLeft, bottomRight, done
}

enum DominantEye: String {
    case left, right
}

class GazeEstimator: ObservableObject {
    @MainActor @Published var gazePoint: CGPoint = CGPoint(x: 960, y: 540)
    @MainActor @Published var isTracking = false
    @MainActor @Published var debugInfo: String = "Starting..."
    @MainActor @Published var calibrationCorner: CalibrationCorner = .none

    var dominantEye: DominantEye = .left
    
    private let lock = NSLock()
    private var targetPoint: CGPoint = CGPoint(x: 960, y: 540)
    private var displayPoint: CGPoint = CGPoint(x: 960, y: 540)
    
    private let springStiffness: CGFloat = 0.15
    
    private var process: Process?
    private var timer: Timer?
    private let processQueue = DispatchQueue(label: "com.iris.python", qos: .userInteractive)
    
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
        }
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
