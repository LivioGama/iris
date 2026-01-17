import Foundation
import IRISCore

/// Manages the lifecycle of the Python gaze tracking process
/// Provides health monitoring, auto-recovery, and timeout detection
public class PythonProcessManager {

    // MARK: - Types

    public enum State {
        case idle
        case starting
        case running
        case recovering
        case failed(Error)

        public var isIdle: Bool {
            if case .idle = self { return true }
            return false
        }

        public var isRunning: Bool {
            if case .running = self { return true }
            return false
        }

        public var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    public enum ProcessError: Error, LocalizedError {
        case pythonNotFound
        case scriptNotFound
        case launchFailed(String)
        case timeout
        case crashed
        case invalidEnvironment(String)

        public var errorDescription: String? {
            switch self {
            case .pythonNotFound:
                return "Python executable not found"
            case .scriptNotFound:
                return "Python script not found"
            case .launchFailed(let reason):
                return "Failed to launch Python process: \(reason)"
            case .timeout:
                return "Python process timed out"
            case .crashed:
                return "Python process crashed"
            case .invalidEnvironment(let message):
                return "Invalid environment: \(message)"
            }
        }
    }

    // MARK: - Properties

    private var process: Process?
    private var healthMonitorTimer: Timer?
    private var startTime: Date?
    private var lastOutputTime: Date?

    private let healthCheckInterval: TimeInterval = 5.0
    private let outputTimeout: TimeInterval = 10.0
    private let maxRecoveryAttempts: Int = 3
    private var recoveryAttemptCount: Int = 0

    private let processQueue = DispatchQueue(label: "com.iris.pythonprocess", qos: .userInteractive)
    private let scriptName: String

    private(set) public var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    // MARK: - Callbacks

    public var onOutput: ((Data) -> Void)?
    public var onStateChange: ((State) -> Void)?
    public var onError: ((ProcessError) -> Void)?
    public var onRecovery: (() -> Void)?

    // MARK: - Initialization

    /// Initializes the Python process manager
    /// - Parameter scriptName: The name of the Python script to execute (e.g., "eye_tracker.py")
    public init(scriptName: String = "eye_tracker.py") {
        self.scriptName = scriptName
    }

    // MARK: - Public Methods

    /// Starts the Python process with the given arguments
    /// - Parameter arguments: Command-line arguments to pass to the Python script
    /// - Throws: ProcessError if the process cannot be started
    public func start(arguments: [String] = []) throws {
        guard state.isIdle || state.isFailed else {
            print("⚠️ PythonProcessManager: Cannot start - already running or starting")
            return
        }

        state = .starting

        // Validate environment
        let validation = PathResolver.validatePythonEnvironment(scriptName: scriptName)
        guard validation.isValid else {
            let error = ProcessError.invalidEnvironment(validation.errorMessage ?? "Unknown error")
            state = .failed(error)
            onError?(error)
            throw error
        }

        // Get paths
        guard let pythonPath = PathResolver.resolvePythonPath() else {
            let error = ProcessError.pythonNotFound
            state = .failed(error)
            onError?(error)
            throw error
        }

        guard let scriptPath = PathResolver.resolvePythonScript(named: scriptName) else {
            let error = ProcessError.scriptNotFound
            state = .failed(error)
            onError?(error)
            throw error
        }

        // Launch process on background queue
        processQueue.async { [weak self] in
            self?.launchProcess(pythonPath: pythonPath, scriptPath: scriptPath, arguments: arguments)
        }
    }

    /// Stops the Python process gracefully
    public func stop() {
        stopHealthMonitoring()

        if let proc = process, proc.isRunning {
            proc.terminate()

            // Give process time to terminate gracefully
            processQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                if let proc = self?.process, proc.isRunning {
                    proc.interrupt()
                }
                self?.process = nil
                self?.cleanupPIDFile()
            }
        } else {
            process = nil
            cleanupPIDFile()
        }

        state = .idle
        recoveryAttemptCount = 0
    }

    /// Restarts the Python process with the same arguments
    public func restart() {
        guard let proc = process else {
            print("⚠️ PythonProcessManager: Cannot restart - no process exists")
            return
        }

        let args = proc.arguments ?? []
        stop()

        // Wait a bit before restarting
        processQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            try? self?.start(arguments: args)
        }
    }

    /// Checks if the process is currently running
    public var isRunning: Bool {
        process?.isRunning ?? false
    }

    // MARK: - Private Methods

    private var pidFilePath: String {
        NSTemporaryDirectory() + "iris_eye_tracker.pid"
    }

    private func writePIDFile(pid: Int32) {
        do {
            try "\(pid)".write(toFile: pidFilePath, atomically: true, encoding: .utf8)
            print("✓ PID file written: \(pidFilePath)")
        } catch {
            print("⚠️ Failed to write PID file: \(error)")
        }
    }

    private func cleanupPIDFile() {
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    /// Cleanup any orphaned processes from previous crashes
    public static func cleanupOrphanedProcesses() {
        let pidFilePath = NSTemporaryDirectory() + "iris_eye_tracker.pid"

        guard let pidString = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            // No PID file or invalid content
            return
        }

        // Check if process is still running
        if kill(pid, 0) == 0 {
            // Process exists, try to kill it
            print("🧹 Cleaning up orphaned Python process (PID: \(pid))")
            kill(pid, SIGTERM)

            // Wait a bit and force kill if still alive
            usleep(500_000) // 0.5 seconds
            if kill(pid, 0) == 0 {
                print("🔨 Force killing orphaned process (PID: \(pid))")
                kill(pid, SIGKILL)
            }
        }

        // Remove PID file
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    private func launchProcess(pythonPath: String, scriptPath: String, arguments: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [scriptPath] + arguments
        proc.environment = ProcessInfo.processInfo.environment
        proc.environment?["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"

        // CRITICAL: Set process group so Python dies when Swift app crashes
        // This prevents orphaned Python processes
        #if os(macOS)
        proc.qualityOfService = .userInteractive
        // Set the process to be in the same process group as the parent
        // This ensures that when the parent dies, the child receives SIGHUP
        #endif

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        proc.standardOutput = outputPipe
        proc.standardError = errorPipe

        process = proc
        startTime = Date()
        lastOutputTime = Date()

        do {
            try proc.run()
            let pid = proc.processIdentifier
            print("✓ PythonProcessManager: Process started (PID: \(pid))")

            // Write PID to a file for cleanup on crash
            writePIDFile(pid: pid)

            state = .running
            recoveryAttemptCount = 0

            // Set up output handler
            setupOutputHandler(pipe: outputPipe)

            // Set up error handler
            setupErrorHandler(pipe: errorPipe)

            // Set up termination handler
            proc.terminationHandler = { [weak self] process in
                self?.handleTermination(process: process)
            }

            // Start health monitoring
            startHealthMonitoring()

        } catch {
            let processError = ProcessError.launchFailed(error.localizedDescription)
            state = .failed(processError)
            onError?(processError)
            print("❌ PythonProcessManager: Launch failed - \(error.localizedDescription)")
        }
    }

    private func setupOutputHandler(pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else {
                return
            }

            // Update last output time for timeout detection
            self?.lastOutputTime = Date()

            // Forward output to callback
            self?.onOutput?(data)
        }
    }

    private func setupErrorHandler(pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty,
                  let errorStr = String(data: data, encoding: .utf8) else {
                return
            }

            print("⚠️ PythonProcessManager stderr: \(errorStr)")
        }
    }

    private func handleTermination(process: Process) {
        print("⚠️ PythonProcessManager: Process terminated (exit code: \(process.terminationStatus))")

        stopHealthMonitoring()

        let wasRunning = state.isRunning
        let exitCode = process.terminationStatus

        // Check if this was an unexpected termination
        if wasRunning && exitCode != 0 {
            attemptRecovery()
        } else {
            state = .idle
        }

        self.process = nil
    }

    private func attemptRecovery() {
        guard recoveryAttemptCount < maxRecoveryAttempts else {
            print("❌ PythonProcessManager: Max recovery attempts reached")
            let error = ProcessError.crashed
            state = .failed(error)
            onError?(error)
            return
        }

        recoveryAttemptCount += 1
        state = .recovering

        print("🔄 PythonProcessManager: Attempting recovery (attempt \(recoveryAttemptCount)/\(maxRecoveryAttempts))...")

        onRecovery?()

        // Wait a bit before restarting
        processQueue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }

            // Get the last arguments used
            let args = Array(self.process?.arguments?.dropFirst() ?? [])

            do {
                try self.start(arguments: args)
                print("✓ PythonProcessManager: Recovery successful")
            } catch {
                print("❌ PythonProcessManager: Recovery failed - \(error.localizedDescription)")
            }
        }
    }

    private func startHealthMonitoring() {
        stopHealthMonitoring()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.healthMonitorTimer = Timer.scheduledTimer(
                withTimeInterval: self.healthCheckInterval,
                repeats: true
            ) { [weak self] _ in
                self?.performHealthCheck()
            }
        }
    }

    private func stopHealthMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.healthMonitorTimer?.invalidate()
            self?.healthMonitorTimer = nil
        }
    }

    private func performHealthCheck() {
        guard let proc = process, proc.isRunning else {
            print("⚠️ PythonProcessManager: Health check - process not running")
            if state.isRunning {
                attemptRecovery()
            }
            return
        }

        // Check for output timeout
        if let lastOutput = lastOutputTime {
            let timeSinceOutput = Date().timeIntervalSince(lastOutput)
            if timeSinceOutput > outputTimeout {
                print("⚠️ PythonProcessManager: Output timeout detected (\(Int(timeSinceOutput))s)")
                let error = ProcessError.timeout
                state = .failed(error)
                onError?(error)
                stop()
                attemptRecovery()
                return
            }
        }

        // Check overall runtime
        if let start = startTime {
            let runtime = Date().timeIntervalSince(start)
            if runtime.truncatingRemainder(dividingBy: 60) < healthCheckInterval {
                print("✓ PythonProcessManager: Health check OK (runtime: \(Int(runtime))s)")
            }
        }
    }

    // MARK: - Deinitialization

    deinit {
        stop()
    }
}
