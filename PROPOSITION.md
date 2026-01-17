# Architecture Audit & Modernization Plan

This document outlines a plan to modernize the `iris2` codebase by replacing fragile manual implementations with robust, native macOS frameworks. The analysis reveals that the current "manual" approach in several key areas (Gaze Tracking, Computer Vision, Camera Management) introduces unnecessary complexity, performance overhead, and instability.

## 1. Executive Summary

| Component | Current Implementation | Problem | Proposed Solution |
|-----------|------------------------|---------|-------------------|
| **Gaze Tracking** | Python Process + MediaPipe + Stdout IPC | Fragile dependencies, process management overhead, sync issues. | **Native Swift + Vision Framework** (`VNDetectFaceLandmarksRequest`). |
| **UI Detection** | Manual Pixel-level loops in Swift (`ComputerVisionDetector.swift`) | Slow O(N) CPU operations, fragile heuristics, reinventing the wheel. | **Vision Framework** (Saliency/Rectangles) + **Accessibility API** (`AXUIElement`). |
| **Camera** | `AVCaptureSession` on Main Thread | Blocking UI calls, potential freezes. | **Async `AVCaptureSession`** Configuration on Background Queue. |
| **Process Mgmt** | `PythonProcessManager` (Manual PID/Health checks) | Complex, error-prone, hard to recover. | **Delete**. Native solution requires no subprocess. |

---

## 2. Detailed Propositions

### A. Gaze Tracking: Remove Python Dependency
**Current**: The app bundles `eye_tracker.py`, manages a Python environment, `mediapipe` dependencies, and communicates via stdin/stdout binary protocol.
**Issues**:
- Requires packaging a Python runtime or relying on system Python (brittle).
- JSON/Binary serialization overhead.
- Process crashes require complex recovery logic.

**Proposition**: Use Apple's native **Vision Framework**.
- **Class**: `VNDetectFaceLandmarksRequest`
- **Benefits**:
    - **Zero External Dependencies**: No Python, no MediaPipe. Built-in to macOS.
    - **Performance**: Hardware accelerated on Neural Engine/GPU.
    - **Data Flow**: `CMSampleBuffer` flows directly from Camera -> Vision Request -> Gaze Coordinates in milliseconds within the same process.
- **Implementation Plan**:
    1. Create `VisionGazeTracker` in `IRISGaze`.
    2. Input `CMSampleBuffer` from `CameraService`.
    3. Extract landmarks (eyes, nose, face contour).
    4. Implement the same smoothing/mapping logic logic in Swift.
    5. Delete `IRISGaze/Sources/Tracking/PythonProcessManager.swift` and `eye_tracker.py`.

### B. UI Element Detection: Modernize Computer Vision
**Current**: `ComputerVisionDetector.swift` manually iterates over pixel grids to find edges and rectangles.
**Issues**:
- **Inefficient**: Pure Swift loop over simple boolean arrays is cache-inefficient and slow for high-res screens.
- **Fragile**: "Flood fill" algo breaks with gradients, shadows, or complex modern UI.
- **Maintenance**: >400 lines of complex geometry code to maintain.

**Proposition**: Leverage **Vision Framework** & **Accessibility API**.
1. **Visual Detection**: Use `VNDetectTextRectanglesRequest` (for text blocks) and `VNDetectRectanglesRequest` (for shapes).
    - These are highly optimized and robust against noise.
2. **Logical Detection**: Rely primarily on `AXUIElement` (Accessibility API) which provides the *actual* bounds of buttons/windows, guaranteed correct by the OS.
    - Only use Visual Detection as a fallback or for non-accessible apps.

### C. Camera Service: Fix Threading
**Current**: `CameraService.start()` calls `session.startRunning()` on the `@MainActor`.
**Issues**: `startRunning()` is a blocking call that can take 100-500ms, causing the app launch or camera toggle to "hitch" or freeze the UI.

**Proposition**:
- Move `session.startRunning()` and configuration to a background serial dispatch queue (`cameraQueue`).
- Only update `@Published` properties on MainActor.
- Use `AVCaptureVideoDataOutput`'s delegate queue effectively.

## 3. Library Recommendations

Instead of manual implementation, consider these standard libraries:

| Capability | Recommended Library / Framework | Why? |
|------------|---------------------------------|------|
| **Logging** | **OSLog** (Unified Logging) | Native, zero-overhead when disabled, structured logging console. Replaces `print`. |
| **Networking** | **URLSession** (Built-in) or **Alamofire** | Currently decent, but ensure `IRISNetwork` uses `async/await` robustly with retries. |
| **State** | **Observation** (macOS 14+) | Replace `Combine` `@Published` where possible for simpler, efficient state tracking. |

## 4. Roadmap

1.  **Phase 1: Stabilization**
    *   Refactor `CameraService` to be async/non-blocking.
    *   Replace manual Logging with `Logger` (OSLog).
2.  **Phase 2: Core Replacement (The Big Win)**
    *   Implement `NativeGazeTracker` using `VNDetectFaceLandmarksRequest`.
    *   Verify accuracy matches or exceeds Python version.
    *   Step-by-step removal of Python code.
3.  **Phase 3: Cleanup**
    *   Remove `PythonProcessManager`.
    *   Remove `ComputerVisionDetector` in favor of Vision/AX.

This plan moves `iris2` from a "prototype-style" hybrid app to a "production-grade" native macOS application.
