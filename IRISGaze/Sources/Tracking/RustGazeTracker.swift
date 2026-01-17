import Foundation
import CIrisGaze

fileprivate func logToFile(_ msg: String) {
    guard ProcessInfo.processInfo.environment["IRIS_VERBOSE_LOGS"] == "1" else { return }
    let line = msg + "\n"
    let path = "/tmp/iris_startup.log"
    if let fileHandle = FileHandle(forWritingAtPath: path) {
        fileHandle.seekToEndOfFile()
        fileHandle.write(line.data(using: .utf8)!)
        fileHandle.closeFile()
    } else {
        try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

/// Manages the Rust gaze tracking library
/// Replaces PythonProcessManager with direct FFI calls for lower latency
public class RustGazeTracker {

    // MARK: - Types

    public enum BlinkEye: UInt8 {
        case none = 0
        case left = 1
        case right = 2
        case both = 3
    }

    public enum State {
        case idle
        case starting
        case running
        case paused
        case failed(Error)

        public var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    public enum TrackerError: Error, LocalizedError {
        case initializationFailed
        case cameraError
        case modelError
        case notInitialized

        public var errorDescription: String? {
            switch self {
            case .initializationFailed:
                return "Failed to initialize gaze tracker"
            case .cameraError:
                return "Camera error"
            case .modelError:
                return "ML model error"
            case .notInitialized:
                return "Tracker not initialized"
            }
        }
    }

    // MARK: - Properties

    private var tracker: OpaquePointer?
    private var pollTimer: DispatchSourceTimer?
    private let pollQueue = DispatchQueue(label: "com.iris.rustgaze", qos: .userInteractive)

    private(set) public var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    // MARK: - Callbacks

    /// Called when gaze position updates
    public var onGaze: ((Double, Double) -> Void)?

    /// Called when tracker state changes
    public var onStateChange: ((State) -> Void)?

    /// Called on errors
    public var onError: ((TrackerError) -> Void)?

    // MARK: - Initialization

    public init() {}

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Start the gaze tracker
    /// - Parameters:
    ///   - screenWidth: Target screen width in pixels
    ///   - screenHeight: Target screen height in pixels
    ///   - dominantEye: Which eye to prioritize ("left" or "right")
    public func start(screenWidth: Int, screenHeight: Int, cameraIndex: Int = 0, dominantEye: String = "left") throws {
        guard tracker == nil else {
            print("⚠️ RustGazeTracker: Already running")
            return
        }

        state = .starting

        print("🦀 RustGazeTracker: Initializing with \(screenWidth)x\(screenHeight), cam: \(cameraIndex), eye: \(dominantEye)")
        logToFile("🦀 RustGazeTracker: About to call iris_gaze_init with index \(cameraIndex)")

        // Initialize the Rust tracker
        let eyeCString = dominantEye.cString(using: .utf8)
        logToFile("🦀 Calling iris_gaze_init now...")
        tracker = iris_gaze_init(Int32(screenWidth), Int32(screenHeight), Int32(cameraIndex), eyeCString)
        logToFile("🦀 iris_gaze_init returned: \(String(describing: tracker))")

        guard tracker != nil else {
            let error = TrackerError.initializationFailed
            logToFile("❌ RustGazeTracker: initializationFailed (null pointer)")
            state = .failed(error)
            onError?(error)
            throw error
        }

        checkError() // Check if camera opened successfully
        if case .failed(let err) = state {
            logToFile("❌ RustGazeTracker: Initial checkError reported failure: \(err.localizedDescription)")
            throw err
        }

        state = .running
        startPolling()

        print("✅ RustGazeTracker: Started successfully")
    }

    /// Stop the gaze tracker
    public func stop() {
        stopPolling()

        if let tracker = tracker {
            iris_gaze_stop(tracker)
            iris_gaze_destroy(tracker)
            self.tracker = nil
        }

        state = .idle
        print("🦀 RustGazeTracker: Stopped")
    }

    /// Pause tracking (keeps camera open)
    public func pause() {
        guard let tracker = tracker else { return }
        iris_gaze_pause(tracker)
        stopPolling()
        state = .paused
    }

    /// Resume tracking
    public func resume() {
        guard let tracker = tracker else { return }
        iris_gaze_resume(tracker)
        startPolling()
        state = .running
    }

    /// Update screen dimensions (e.g., when display changes)
    public func setScreenSize(width: Int, height: Int) {
        guard let tracker = tracker else { return }
        iris_gaze_set_screen_size(tracker, Int32(width), Int32(height))
    }

    /// Check if tracker is running
    public var isRunning: Bool {
        guard let tracker = tracker else { return false }
        return iris_gaze_get_status(tracker) == Running
    }

    // MARK: - Private Methods

    private func startPolling() {
        stopPolling()

        logToFile("🦀 RustGazeTracker: startPolling() called")

        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))  // 60 FPS (was 33ms/30fps)
        timer.setEventHandler { [weak self] in
            self?.pollFrame()
        }
        pollTimer = timer
        timer.resume()
    }

    private func stopPolling() {
        pollTimer?.setEventHandler {}
        pollTimer?.cancel()
        pollTimer = nil
    }

    private var pollCount = 0

    private func pollFrame() {
        pollCount += 1
        guard let tracker = tracker else {
            return
        }

        // Get next frame result from Rust
        let result = iris_gaze_get_frame(tracker)


        if !result.valid {
            checkError()
            return
        }

        switch result.event_type {
        case 1: // Gaze
            onGaze?(result.x, result.y)

        default:
            break
        }
    }

    private func checkError() {
        guard let tracker = tracker else { return }

        let error = iris_gaze_get_error(tracker)
        switch error {
        case CameraError:
            let err = TrackerError.cameraError
            state = .failed(err)
            onError?(err)
        case ModelError:
            let err = TrackerError.modelError
            state = .failed(err)
            onError?(err)
        default:
            break
        }
    }
}
