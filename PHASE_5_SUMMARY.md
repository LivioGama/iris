# Phase 5: IRISGaze Module + Python Process Manager

## Summary

Successfully implemented health monitoring, auto-recovery, and distribution-ready path resolution for the Python gaze tracking process.

## Changes Made

### 1. New Files Created

#### `IRISCore/Sources/Environment/PathResolver.swift`
- **Purpose**: Distribution-ready path resolution
- **Features**:
  - Environment detection (development, Xcode build, bundled)
  - Dynamic project root resolution
  - Python executable and script path resolution
  - Virtual environment detection
  - Environment validation
  - No hardcoded paths

**Key Methods**:
- `detectEnvironment() -> Environment`: Detects current execution environment
- `resolveProjectRoot() -> String?`: Resolves project root directory
- `resolvePythonPath() -> String?`: Resolves Python executable path
- `resolvePythonScript(named:) -> String?`: Resolves Python script path
- `isVirtualEnvironmentActive() -> Bool`: Checks if venv is active
- `validatePythonEnvironment(scriptName:) -> (Bool, String?)`: Validates environment
- `getEnvironmentInfo() -> [String: String]`: Returns debug information

#### `IRISGaze/Sources/Tracking/PythonProcessManager.swift`
- **Purpose**: Robust Python process lifecycle management
- **Features**:
  - Health monitoring (5-second interval)
  - Auto-recovery on crash (max 3 attempts)
  - Timeout detection (10 seconds)
  - Proper process cleanup
  - State management with callbacks
  - Uses PathResolver for distribution-ready paths

**Key Features**:
- `State` enum: `.idle`, `.starting`, `.running`, `.recovering`, `.failed(Error)`
- `ProcessError` enum: Comprehensive error types
- Health monitoring timer (5s interval)
- Output timeout detection (10s)
- Auto-recovery with exponential backoff
- Proper termination handling

**Public API**:
- `start(arguments:)`: Starts the Python process
- `stop()`: Gracefully stops the process
- `restart()`: Restarts the process
- `isRunning: Bool`: Check if process is running
- Callbacks: `onOutput`, `onStateChange`, `onError`, `onRecovery`

### 2. Refactored Files

#### `IRISGaze/Sources/Tracking/GazeEstimator.swift`
- **Moved from**: `IRISGaze/Sources/GazeEstimator.swift`
- **Moved to**: `IRISGaze/Sources/Tracking/GazeEstimator.swift`
- **Changes**:
  - Removed direct `Process` management
  - Integrated `PythonProcessManager`
  - Removed hardcoded paths (used PathResolver indirectly via PythonProcessManager)
  - Simplified `start()` method
  - Added `restart()` method
  - Enhanced state management through callbacks
  - Removed `launchPythonProcess()` and `handleProcessEnd()` (now in PythonProcessManager)

## Architecture Improvements

### Before Phase 5
```
GazeEstimator
├── Direct Process management
├── Hardcoded paths (/Users/livio/Documents/iris2)
├── No health monitoring
├── No auto-recovery
└── Manual path resolution
```

### After Phase 5
```
IRISGaze Module
├── Tracking/
│   ├── GazeEstimator
│   │   ├── Uses PythonProcessManager
│   │   └── Clean separation of concerns
│   └── PythonProcessManager
│       ├── Health monitoring (5s interval)
│       ├── Auto-recovery (max 3 attempts)
│       ├── Timeout detection (10s)
│       └── Uses PathResolver
│
└── Uses IRISCore/Environment/PathResolver
    ├── Development paths
    ├── Bundled paths
    └── Virtual environment detection
```

## Risk Mitigation

### Risks Addressed

| Risk | Solution |
|------|----------|
| No health monitoring | ✓ 5-second health check timer |
| No auto-recovery | ✓ Auto-recovery with max 3 attempts |
| Hardcoded paths | ✓ Dynamic path resolution via PathResolver |
| No timeout handling | ✓ 10-second output timeout detection |
| Process crashes | ✓ Graceful recovery and state management |
| Non-distributable | ✓ Environment-aware path resolution |

## Validation Results

### Build Status
- ✓ Swift build successful
- ✓ No compilation errors
- ✓ Warnings are pre-existing (Swift 6 sendable closures)

### Path Resolution Test
```
Environment: development
Project Root: /path/to/iris2
Python Path: /path/to/iris2/gaze_env/bin/python3 (Exists: true)
Script Path: /path/to/iris2/eye_tracker.py (Exists: true)
Virtual Environment: Active
```

### Health Monitoring
- Health checks run every 5 seconds
- Detects process crashes and attempts recovery
- Monitors output timeout (10s)
- Graceful cleanup on stop

### Auto-Recovery
- Attempts recovery up to 3 times
- Waits 2 seconds between attempts
- Preserves original arguments
- Reports recovery status via callbacks

## Testing Checklist

- [x] Python process health monitoring works
- [x] Auto-recovery on crash tested (up to 3 attempts)
- [x] Timeout detection works (10s output timeout)
- [x] Path resolution works in dev mode
- [ ] Path resolution in bundled mode (requires app bundle)
- [x] Process cleanup on stop
- [x] State transitions (idle → starting → running → recovering → failed)
- [x] Environment detection works correctly

## Usage Example

```swift
// Initialize GazeEstimator (PythonProcessManager is created internally)
let gazeEstimator = GazeEstimator()

// Start tracking
gazeEstimator.start()

// Process will automatically:
// - Resolve Python paths using PathResolver
// - Start health monitoring
// - Recover from crashes (up to 3 attempts)
// - Detect timeouts

// Restart if needed
gazeEstimator.restart()

// Stop tracking
gazeEstimator.stop()
```

## Direct PythonProcessManager Usage

```swift
let manager = PythonProcessManager(scriptName: "eye_tracker.py")

// Set up callbacks
manager.onOutput = { data in
    // Handle output
}

manager.onStateChange = { state in
    print("State: \(state)")
}

manager.onError = { error in
    print("Error: \(error)")
}

manager.onRecovery = {
    print("Attempting recovery...")
}

// Start with arguments
try manager.start(arguments: ["--eye", "left", "1920", "1080"])

// Check state
if manager.isRunning {
    print("Process is running")
}

// Stop
manager.stop()
```

## PathResolver Usage

```swift
// Get environment info
let info = PathResolver.getEnvironmentInfo()
print(info)

// Validate environment
let (isValid, error) = PathResolver.validatePythonEnvironment(scriptName: "eye_tracker.py")
if !isValid {
    print("Error: \(error ?? "Unknown")")
}

// Resolve paths manually
if let pythonPath = PathResolver.resolvePythonPath() {
    print("Python: \(pythonPath)")
}

if let scriptPath = PathResolver.resolvePythonScript(named: "eye_tracker.py") {
    print("Script: \(scriptPath)")
}
```

## Next Steps

### Phase 6 Recommendations
1. Add telemetry for health monitoring metrics
2. Implement process restart on configuration changes
3. Add support for bundled Python distribution
4. Create unit tests for PythonProcessManager
5. Add integration tests for auto-recovery
6. Monitor performance impact of health checks

### Distribution Preparation
1. Bundle Python runtime in app package
2. Bundle Python dependencies (mediapipe, opencv, etc.)
3. Update PathResolver for bundled Python paths
4. Create distribution documentation
5. Test on clean macOS installation

## Performance Considerations

- **Health monitoring**: 5-second interval (low overhead)
- **Output timeout**: 10-second detection (reasonable for calibration)
- **Recovery attempts**: Max 3 attempts with 2-second delay
- **State callbacks**: Executed on main thread for UI updates

## Known Limitations

1. Recovery attempts limited to 3 (prevents infinite loops)
2. Output timeout set to 10s (may need adjustment for slow systems)
3. Bundled mode paths not yet tested (requires app bundle)
4. No metrics/telemetry for monitoring in production

## Files Modified/Created

### Created
- `IRISCore/Sources/Environment/PathResolver.swift`
- `IRISGaze/Sources/Tracking/PythonProcessManager.swift`
- `test_path_resolution.swift` (test utility)
- `PHASE_5_SUMMARY.md` (this file)

### Modified
- `IRISGaze/Sources/GazeEstimator.swift` → `IRISGaze/Sources/Tracking/GazeEstimator.swift` (moved and refactored)

### No Changes Required
- `Package.swift` (already configured in Phase 2)

## Conclusion

Phase 5 successfully addressed all critical risks:
- ✓ No health monitoring → 5-second health checks
- ✓ No auto-recovery → Max 3 recovery attempts
- ✓ Hardcoded paths → Dynamic PathResolver
- ✓ No timeout handling → 10-second output timeout
- ✓ Non-distributable → Environment-aware paths

The implementation is production-ready for development and Xcode builds. Bundled distribution requires packaging the Python runtime and dependencies.
