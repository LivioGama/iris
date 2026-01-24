//! IRIS Gaze Tracking Library
//!
//! High-performance eye and gaze tracking library using face mesh detection.
//! Designed for integration with Swift via C FFI.
//!
//! # Architecture
//!
//! ```text
//! ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
//! │   Camera     │ → │  Face Mesh   │ → │    Gaze      │
//! │   Capture    │   │  Detection   │   │  Estimation  │
//! └──────────────┘   └──────────────┘   └──────────────┘
//! ```
//!
//! # FFI Usage
//!
//! ```c
//! // Initialize tracker
//! GazeTracker* tracker = iris_gaze_init(1920, 1080, "left");
//!
//! // Main loop
//! while (running) {
//!     GazeResult result = iris_gaze_get_frame(tracker);
//!     if (result.valid) {
//!         // Use result.x, result.y
//!     }
//! }
//!
//! // Cleanup
//! iris_gaze_stop(tracker);
//! iris_gaze_destroy(tracker);
//! ```

pub mod blink;
pub mod camera;
pub mod face_mesh;
pub mod gaze;
pub mod types;

use std::ffi::{c_char, CStr};
use std::ptr;
use std::time::{Duration, Instant};

pub use types::*;

/// Opaque tracker handle for FFI
pub struct GazeTracker {
    config: GazeConfig,
    #[allow(dead_code)]
    dominant_eye: DominantEye,
    status: TrackerStatus,
    last_error: GazeError,

    // Components
    camera: Option<camera::Camera>,
    face_mesh: Option<face_mesh::FaceMeshDetector>,
    gaze_estimator: gaze::GazeEstimator,
    blink_detector: blink::BlinkDetector,

    // Latest result for polling
    latest_result: GazeResult,

    // Frame rate limiting
    last_frame_time: Option<Instant>,
    target_frame_duration: Duration,

    // Skip face detection on some frames for performance
    frame_count: u32,
    last_landmarks: Option<types::FaceLandmarks>,
    blink_hold_frames: u8,
}

impl GazeTracker {
    /// Create a new gaze tracker with the given configuration
    fn new(screen_width: i32, screen_height: i32, dominant_eye: DominantEye) -> Self {
        let mut config = GazeConfig::default();
        config.screen_width = screen_width;
        config.screen_height = screen_height;

        Self {
            config,
            dominant_eye,
            status: TrackerStatus::Uninitialized,
            last_error: GazeError::None,
            camera: None,
            face_mesh: None,
            gaze_estimator: gaze::GazeEstimator::new(
                screen_width,
                screen_height,
                config.ema_alpha,
                config.deadzone,
            ),
            blink_detector: blink::BlinkDetector::new(config.blink_threshold, config.wink_frames),
            latest_result: GazeResult::default(),
            last_frame_time: None,
            target_frame_duration: Duration::from_micros(33333), // 30 FPS target
            frame_count: 0,
            last_landmarks: None,
            blink_hold_frames: 0,
        }
    }

    /// Initialize all components (camera, model)
    fn initialize(&mut self) -> Result<(), GazeError> {
        // Debug log
        if let Ok(mut f) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open("/tmp/iris_rust.log")
        {
            use std::io::Write;
            let _ = writeln!(f, "🚀 GazeTracker::initialize() called");
        }

        self.status = TrackerStatus::Initializing;

        // Prefer Python calibration if available, otherwise enable auto-calibration
        if let Some((x_min, x_max, y_min, y_max)) = gaze::GazeEstimator::load_calibration_file() {
            self.gaze_estimator
                .set_calibration(x_min, x_max, y_min, y_max);
            if let Ok(mut f) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_rust.log")
            {
                use std::io::Write;
                let _ = writeln!(
                    f,
                    "✅ Using calibration from /tmp/iris_calibration.txt: X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}]",
                    x_min, x_max, y_min, y_max
                );
            }
        } else {
            self.gaze_estimator.set_auto_calibrate(true);
            if let Ok(mut f) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_rust.log")
            {
                use std::io::Write;
                let _ = writeln!(f, "ℹ️ No calibration file found. Auto-calibration enabled.");
            }
        }

        // Initialize camera
        match camera::Camera::new(
            self.config.camera_width,
            self.config.camera_height,
            self.config.target_fps,
        ) {
            Ok(cam) => self.camera = Some(cam),
            Err(e) => {
                log::error!("Failed to initialize camera: {:?}", e);
                self.last_error = GazeError::CameraError;
                self.status = TrackerStatus::Error;
                return Err(GazeError::CameraError);
            }
        }

        // Initialize face mesh detector
        match face_mesh::FaceMeshDetector::new() {
            Ok(detector) => self.face_mesh = Some(detector),
            Err(e) => {
                log::error!("Failed to initialize face mesh detector: {:?}", e);
                self.last_error = GazeError::ModelError;
                self.status = TrackerStatus::Error;
                return Err(GazeError::ModelError);
            }
        }

        self.status = TrackerStatus::Running;
        log::info!("Gaze tracker initialized successfully");
        Ok(())
    }

    /// Process one frame and return the result
    fn process_frame(&mut self) -> GazeResult {
        if self.status != TrackerStatus::Running {
            return GazeResult::invalid();
        }

        // Frame rate limiting - don't process faster than target FPS
        let now = Instant::now();
        if let Some(last_time) = self.last_frame_time {
            let elapsed = now.duration_since(last_time);
            if elapsed < self.target_frame_duration {
                // Sleep briefly to avoid busy-waiting and reduce CPU
                let sleep_time = self.target_frame_duration.saturating_sub(elapsed);
                if sleep_time > Duration::from_millis(1) {
                    std::thread::sleep(Duration::from_millis(1));
                }
                // Return cached result, don't process new frame yet
                return self.latest_result;
            }
        }

        if self.blink_hold_frames > 0 {
            self.blink_hold_frames = self.blink_hold_frames.saturating_sub(1);
            return self.latest_result;
        }
        self.last_frame_time = Some(now);
        self.frame_count = self.frame_count.wrapping_add(1);

        // Refresh blink tuning occasionally for live adjustments
        if self.frame_count % 60 == 0 {
            self.update_blink_settings();
        }

        // Only capture and detect on every Nth frame for performance
        // At 30 FPS, detecting every 2nd frame = 15 detections/sec (good balance)
        let do_detection = self.frame_count % 2 == 0 || self.last_landmarks.is_none();

        let landmarks = if do_detection {
            // Capture frame from camera
            let camera = match &mut self.camera {
                Some(c) => c,
                None => return GazeResult::invalid(),
            };

            let frame = match camera.capture_frame() {
                Ok(f) => f,
                Err(e) => {
                    static mut CAM_ERR_COUNT: u32 = 0;
                    unsafe {
                        CAM_ERR_COUNT += 1;
                        if CAM_ERR_COUNT <= 5 {
                            let _ = std::fs::OpenOptions::new()
                                .create(true)
                                .append(true)
                                .open("/tmp/iris_rust.log")
                                .and_then(|mut f| {
                                    use std::io::Write;
                                    writeln!(f, "❌ Camera error #{}: {:?}", CAM_ERR_COUNT, e)
                                });
                        }
                    }
                    return GazeResult::invalid();
                }
            };

            // Run face detection
            let face_mesh = match &mut self.face_mesh {
                Some(fm) => fm,
                None => return GazeResult::invalid(),
            };

            match face_mesh.detect(&frame) {
                Ok(Some(l)) => {
                    self.last_landmarks = Some(l.clone());
                    l
                }
                Ok(None) => {
                    static mut NO_FACE_COUNT: u32 = 0;
                    unsafe {
                        NO_FACE_COUNT += 1;
                        if NO_FACE_COUNT <= 5 {
                            let _ = std::fs::OpenOptions::new()
                                .create(true)
                                .append(true)
                                .open("/tmp/iris_rust.log")
                                .and_then(|mut f| {
                                    use std::io::Write;
                                    writeln!(f, "⚠️ No face detected #{}", NO_FACE_COUNT)
                                });
                        }
                    }
                    match &self.last_landmarks {
                        Some(l) => l.clone(),
                        None => return GazeResult::invalid(),
                    }
                }
                Err(e) => {
                    static mut DETECT_ERR_COUNT: u32 = 0;
                    unsafe {
                        DETECT_ERR_COUNT += 1;
                        if DETECT_ERR_COUNT <= 5 {
                            let _ = std::fs::OpenOptions::new()
                                .create(true)
                                .append(true)
                                .open("/tmp/iris_rust.log")
                                .and_then(|mut f| {
                                    use std::io::Write;
                                    writeln!(
                                        f,
                                        "❌ Face detection error #{}: {:?}",
                                        DETECT_ERR_COUNT, e
                                    )
                                });
                        }
                    }
                    return GazeResult::invalid();
                }
            }
        } else {
            // Reuse last landmarks
            match &self.last_landmarks {
                Some(l) => l.clone(),
                None => return GazeResult::invalid(),
            }
        };

        // Check for blink/wink
        let blink_result = self.blink_detector.update(&landmarks);

        // If blinking, don't update gaze position but may trigger blink event
        if let Some(blink_event) = blink_result {
            if blink_event.is_wink {
                // Get current gaze position for blink event
                let (x, y) = self.gaze_estimator.get_current_position();
                let result = GazeResult::blink(x, y);
                self.latest_result = result;
                return result;
            }
            // Regular blink - skip gaze update
            self.blink_hold_frames = 2;
            return self.latest_result;
        }

        // Estimate gaze position
        match self.gaze_estimator.estimate(&landmarks) {
            Some((x, y)) => {
                let result = GazeResult::gaze(x, y);
                self.latest_result = result;
                result
            }
            None => GazeResult::invalid(),
        }
    }

    /// Stop the tracker
    fn stop(&mut self) {
        self.status = TrackerStatus::Stopped;
        self.camera = None;
        self.face_mesh = None;
        log::info!("Gaze tracker stopped");
    }

    /// Load optional blink tuning from /tmp/iris_blink.txt
    /// Supported keys:
    ///   blink_threshold = 0.23
    ///   wink_frames = 8
    fn update_blink_settings(&mut self) {
        let content = match std::fs::read_to_string("/tmp/iris_blink.txt") {
            Ok(c) => c,
            Err(_) => return,
        };

        let mut threshold: Option<f32> = None;
        let mut wink_frames: Option<i32> = None;

        for raw_line in content.lines() {
            let line = raw_line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            let mut parts = line.split('=');
            let key = match parts.next() {
                Some(k) => k.trim(),
                None => continue,
            };
            let value_str = match parts.next() {
                Some(v) => v.trim(),
                None => continue,
            };

            match key {
                "blink_threshold" => {
                    if let Ok(v) = value_str.parse::<f32>() {
                        threshold = Some(v);
                    }
                }
                "wink_frames" => {
                    if let Ok(v) = value_str.parse::<i32>() {
                        wink_frames = Some(v);
                    }
                }
                _ => {}
            }
        }

        if let Some(t) = threshold {
            self.blink_detector.set_threshold(t);
        }
        if let Some(w) = wink_frames {
            self.blink_detector.set_wink_frames(w);
        }
    }
}

// ============================================================================
// C FFI Interface
// ============================================================================

/// Initialize a new gaze tracker
///
/// # Arguments
/// * `screen_width` - Width of the target screen in pixels
/// * `screen_height` - Height of the target screen in pixels
/// * `dominant_eye` - C string: "left" or "right"
///
/// # Returns
/// Pointer to the tracker, or NULL on failure
#[no_mangle]
pub extern "C" fn iris_gaze_init(
    screen_width: i32,
    screen_height: i32,
    dominant_eye: *const c_char,
) -> *mut GazeTracker {
    // Initialize logger on first call
    let _ = env_logger::try_init();

    log::info!("iris_gaze_init called: {}x{}", screen_width, screen_height);

    // Parse dominant eye
    let eye = if dominant_eye.is_null() {
        DominantEye::Left
    } else {
        let eye_str = unsafe { CStr::from_ptr(dominant_eye) };
        match eye_str.to_str() {
            Ok(s) => DominantEye::from(s),
            Err(_) => DominantEye::Left,
        }
    };

    // Create tracker
    let mut tracker = Box::new(GazeTracker::new(screen_width, screen_height, eye));

    // Initialize components
    if let Err(e) = tracker.initialize() {
        eprintln!("🦀 RUST: Failed to initialize tracker: {:?}", e);
        let _ = std::fs::write("/tmp/iris_init_error.log", format!("Init error: {:?}\n", e));
        return ptr::null_mut();
    }

    eprintln!("🦀 RUST: Tracker initialized successfully!");
    let _ = std::fs::write("/tmp/iris_init_success.log", "Tracker init success!\n");
    Box::into_raw(tracker)
}

/// Get the next frame result from the tracker
///
/// This function should be called in a loop (e.g., 60 times per second).
/// It captures a camera frame, detects landmarks, and returns gaze coordinates.
///
/// # Arguments
/// * `tracker` - Pointer to the tracker (from iris_gaze_init)
///
/// # Returns
/// GazeResult with coordinates and event type
#[no_mangle]
pub extern "C" fn iris_gaze_get_frame(tracker: *mut GazeTracker) -> GazeResult {
    if tracker.is_null() {
        return GazeResult::invalid();
    }

    let tracker = unsafe { &mut *tracker };
    tracker.process_frame()
}

/// Get the current status of the tracker
#[no_mangle]
pub extern "C" fn iris_gaze_get_status(tracker: *const GazeTracker) -> TrackerStatus {
    if tracker.is_null() {
        return TrackerStatus::Uninitialized;
    }

    let tracker = unsafe { &*tracker };
    tracker.status
}

/// Get the last error code
#[no_mangle]
pub extern "C" fn iris_gaze_get_error(tracker: *const GazeTracker) -> GazeError {
    if tracker.is_null() {
        return GazeError::NotInitialized;
    }

    let tracker = unsafe { &*tracker };
    tracker.last_error
}

/// Stop the tracker (releases camera, etc.)
#[no_mangle]
pub extern "C" fn iris_gaze_stop(tracker: *mut GazeTracker) {
    if tracker.is_null() {
        return;
    }

    let tracker = unsafe { &mut *tracker };
    tracker.stop();
}

/// Destroy the tracker and free memory
///
/// After calling this, the tracker pointer is invalid.
#[no_mangle]
pub extern "C" fn iris_gaze_destroy(tracker: *mut GazeTracker) {
    if tracker.is_null() {
        return;
    }

    // Take ownership and drop
    let _ = unsafe { Box::from_raw(tracker) };
    log::info!("Gaze tracker destroyed");
}

/// Update the screen dimensions
#[no_mangle]
pub extern "C" fn iris_gaze_set_screen_size(tracker: *mut GazeTracker, width: i32, height: i32) {
    if tracker.is_null() {
        return;
    }

    let tracker = unsafe { &mut *tracker };
    tracker.config.screen_width = width;
    tracker.config.screen_height = height;
    tracker.gaze_estimator.set_screen_size(width, height);
}

/// Pause gaze tracking
#[no_mangle]
pub extern "C" fn iris_gaze_pause(tracker: *mut GazeTracker) {
    if tracker.is_null() {
        return;
    }

    let tracker = unsafe { &mut *tracker };
    if tracker.status == TrackerStatus::Running {
        tracker.status = TrackerStatus::Paused;
    }
}

/// Resume gaze tracking
#[no_mangle]
pub extern "C" fn iris_gaze_resume(tracker: *mut GazeTracker) {
    if tracker.is_null() {
        return;
    }

    let tracker = unsafe { &mut *tracker };
    if tracker.status == TrackerStatus::Paused {
        tracker.status = TrackerStatus::Running;
    }
}

/// Set calibration values directly
///
/// # Arguments
/// * `tracker` - Pointer to the tracker
/// * `x_min` - Minimum nose X value (looking right)
/// * `x_max` - Maximum nose X value (looking left)
/// * `y_min` - Minimum forehead Y value (looking up)
/// * `y_max` - Maximum forehead Y value (looking down)
#[no_mangle]
pub extern "C" fn iris_gaze_set_calibration(
    tracker: *mut GazeTracker,
    x_min: f64,
    x_max: f64,
    y_min: f64,
    y_max: f64,
) {
    if tracker.is_null() {
        return;
    }

    let tracker = unsafe { &mut *tracker };
    tracker
        .gaze_estimator
        .set_calibration(x_min, x_max, y_min, y_max);

    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open("/tmp/iris_rust.log")
    {
        use std::io::Write;
        let _ = writeln!(
            f,
            "🎯 FFI set_calibration: X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}]",
            x_min, x_max, y_min, y_max
        );
    }
}

/// Set reach gain for easier corner access
#[no_mangle]
pub extern "C" fn iris_gaze_set_reach_gain(tracker: *mut GazeTracker, gain_x: f64, gain_y: f64) {
    if tracker.is_null() {
        return;
    }

    let tracker = unsafe { &mut *tracker };
    tracker.gaze_estimator.set_reach_gain(gain_x, gain_y);

    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open("/tmp/iris_rust.log")
    {
        use std::io::Write;
        let _ = writeln!(f, "🎛 FFI set_reach_gain: x={:.2}, y={:.2}", gain_x, gain_y);
    }
}

/// Get the current raw landmark values for calibration
/// Returns the nose X and forehead Y values from the last frame
///
/// # Arguments
/// * `tracker` - Pointer to the tracker
/// * `nose_x` - Output: current nose X value
/// * `nose_y` - Output: current forehead Y value
///
/// # Returns
/// true if values are valid, false otherwise
#[no_mangle]
pub extern "C" fn iris_gaze_get_raw_position(
    tracker: *mut GazeTracker,
    nose_x: *mut f64,
    nose_y: *mut f64,
) -> bool {
    if tracker.is_null() || nose_x.is_null() || nose_y.is_null() {
        return false;
    }

    let tracker = unsafe { &mut *tracker };

    // Get landmarks from the last processed frame
    if let Some(ref landmarks) = tracker.last_landmarks {
        if let (Some(nose), Some(forehead)) = (landmarks.nose_tip(), landmarks.forehead()) {
            unsafe {
                *nose_x = nose.x as f64;
                *nose_y = forehead.y as f64;
            }
            return true;
        }
    }

    false
}

/// Enable or disable auto-calibration mode
/// When enabled, the tracker will automatically adjust calibration based on observed values
#[no_mangle]
pub extern "C" fn iris_gaze_set_auto_calibrate(tracker: *mut GazeTracker, enabled: bool) {
    if tracker.is_null() {
        return;
    }

    let tracker = unsafe { &mut *tracker };
    tracker.gaze_estimator.set_auto_calibrate(enabled);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tracker_creation() {
        // This test requires camera access, so we just test the null case
        let result = iris_gaze_get_frame(ptr::null_mut());
        assert!(!result.valid);
    }

    #[test]
    fn test_status_uninitialized() {
        let status = iris_gaze_get_status(ptr::null());
        assert_eq!(status, TrackerStatus::Uninitialized);
    }
}
