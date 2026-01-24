//! IRIS Gaze Tracking Library - Python-equivalent implementation
//!
//! Uses Python MediaPipe for face mesh to get identical coordinates.

pub mod camera;
pub mod face_mesh;
pub mod python_face_mesh;
pub mod types;

use std::ffi::c_char;
use std::ptr;

pub use types::*;
use python_face_mesh::PythonFaceMeshDetector;

fn log(msg: &str) {
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open("/tmp/iris_rust.log")
    {
        use std::io::Write;
        let _ = writeln!(f, "{}", msg);
    }
}

/// Main gaze tracker - mirrors Python implementation
pub struct GazeTracker {
    screen_width: f64,
    screen_height: f64,

    // Python MediaPipe face mesh (gives identical coordinates to Python)
    python_face_mesh: Option<PythonFaceMeshDetector>,

    // Smoothed gaze position (ema_x, ema_y in Python)
    ema_x: f64,
    ema_y: f64,

    // Smoothed nose position (ema_nose_x, ema_nose_y in Python)
    ema_nose_x: f64,
    ema_nose_y: f64,

    // Calibration ranges
    nose_x_min: f64,
    nose_x_max: f64,
    nose_y_min: f64,
    nose_y_max: f64,

    // Auto-calibration: track observed range and slowly adapt
    observed_x_min: f64,
    observed_x_max: f64,
    observed_y_min: f64,
    observed_y_max: f64,

    // Blink detection state
    eye_ar_thresh: f64,
    long_blink_thresh: i32,
    eyes_closed_counter: i32,
    long_blink_triggered: bool,

    // Status
    status: TrackerStatus,
    frame_count: u32,
}

impl GazeTracker {
    fn new(screen_width: i32, screen_height: i32) -> Self {
        let sw = screen_width as f64;
        let sh = screen_height as f64;

        Self {
            screen_width: sw,
            screen_height: sh,
            python_face_mesh: None,
            ema_x: sw / 2.0,
            ema_y: sh / 2.0,
            ema_nose_x: 0.45,  // Will quickly adapt via EMA
            ema_nose_y: 0.42,  // Will quickly adapt via EMA
            // Very wide range to handle coordinate variance
            nose_x_min: 0.15,
            nose_x_max: 0.75,
            nose_y_min: 0.30,
            nose_y_max: 0.55,
            // Auto-calibration: will adapt based on observed values
            observed_x_min: 0.45,
            observed_x_max: 0.45,
            observed_y_min: 0.42,
            observed_y_max: 0.42,
            // Blink detection
            eye_ar_thresh: 0.25,
            long_blink_thresh: 8,
            eyes_closed_counter: 0,
            long_blink_triggered: false,
            status: TrackerStatus::Uninitialized,
            frame_count: 0,
        }
    }

    fn initialize(&mut self) -> Result<(), GazeError> {
        log(&format!("🚀 GazeTracker::initialize() - Cal: X={:.2}-{:.2}, Y={:.2}-{:.2}",
            self.nose_x_min, self.nose_x_max, self.nose_y_min, self.nose_y_max));

        self.status = TrackerStatus::Initializing;

        // Initialize Python MediaPipe face mesh (handles its own camera)
        match PythonFaceMeshDetector::new() {
            Ok(fm) => {
                log("✅ Python MediaPipe FaceMesh initialized");
                self.python_face_mesh = Some(fm);
            }
            Err(e) => {
                log(&format!("❌ Python FaceMesh error: {:?}", e));
                self.status = TrackerStatus::Error;
                return Err(GazeError::ModelError);
            }
        }

        self.status = TrackerStatus::Running;
        log("✅ Tracker ready");
        Ok(())
    }

    fn process_frame(&mut self) -> GazeResult {
        if self.status != TrackerStatus::Running {
            return GazeResult::invalid();
        }

        self.frame_count += 1;

        // Get landmarks from Python MediaPipe
        let face_mesh = match &mut self.python_face_mesh {
            Some(fm) => fm,
            None => return GazeResult::invalid(),
        };

        let landmarks = match face_mesh.detect() {
            Ok(Some(lm)) => lm,
            _ => return GazeResult::invalid(),
        };

        // === BLINK DETECTION (matches Python exactly) ===

        // Left eye landmarks: 159 (top), 145 (bottom), 33 (left), 133 (right)
        let left_eye_top = match landmarks.get(159) { Some(p) => p, None => return GazeResult::invalid() };
        let left_eye_bottom = match landmarks.get(145) { Some(p) => p, None => return GazeResult::invalid() };
        let left_eye_left = match landmarks.get(33) { Some(p) => p, None => return GazeResult::invalid() };
        let left_eye_right = match landmarks.get(133) { Some(p) => p, None => return GazeResult::invalid() };

        let left_vertical = (left_eye_top.y - left_eye_bottom.y).abs();
        let left_horizontal = (left_eye_right.x - left_eye_left.x).abs();
        let left_ear = if left_horizontal > 0.0 { left_vertical / left_horizontal } else { 1.0 };

        // Right eye landmarks: 386 (top), 374 (bottom), 362 (left), 263 (right)
        let right_eye_top = match landmarks.get(386) { Some(p) => p, None => return GazeResult::invalid() };
        let right_eye_bottom = match landmarks.get(374) { Some(p) => p, None => return GazeResult::invalid() };
        let right_eye_left = match landmarks.get(362) { Some(p) => p, None => return GazeResult::invalid() };
        let right_eye_right = match landmarks.get(263) { Some(p) => p, None => return GazeResult::invalid() };

        let right_vertical = (right_eye_top.y - right_eye_bottom.y).abs();
        let right_horizontal = (right_eye_right.x - right_eye_left.x).abs();
        let right_ear = if right_horizontal > 0.0 { right_vertical / right_horizontal } else { 1.0 };

        // Debug EAR every 30 frames
        if self.frame_count % 30 == 0 {
            log(&format!("👁️ L_EAR: {:.3}, R_EAR: {:.3} (thresh: {:.2})",
                left_ear, right_ear, self.eye_ar_thresh));
        }

        // Check for eye close
        let left_closed = (left_ear as f64) < self.eye_ar_thresh;
        let right_closed = (right_ear as f64) < self.eye_ar_thresh;
        let is_winking = left_closed || right_closed;

        if is_winking {
            self.eyes_closed_counter += 1;

            // Long blink trigger
            if self.eyes_closed_counter == self.long_blink_thresh && !self.long_blink_triggered {
                self.long_blink_triggered = true;
                let which = if left_closed { "LEFT" } else { "RIGHT" };
                log(&format!("😉 {} WINK TRIGGERED!", which));
                return GazeResult::blink(self.ema_x, self.ema_y);
            }

            // Don't update gaze during blink
            return GazeResult::gaze(self.ema_x, self.ema_y);
        } else {
            self.eyes_closed_counter = 0;
            self.long_blink_triggered = false;
        }

        // === GAZE TRACKING (matches Python exactly) ===

        // Get nose tip (landmark 4) and forehead (landmark 10)
        let nose = match landmarks.get(4) { Some(p) => p, None => return GazeResult::invalid() };
        let forehead = match landmarks.get(10) { Some(p) => p, None => return GazeResult::invalid() };

        let nose_x = nose.x as f64;
        let nose_y = forehead.y as f64;  // Use forehead Y for vertical

        // EMA smoothing on raw nose position (alpha = 0.25)
        self.ema_nose_x += (nose_x - self.ema_nose_x) * 0.25;
        self.ema_nose_y += (nose_y - self.ema_nose_y) * 0.25;

        // Auto-calibration: track center and expand range symmetrically
        // This keeps the neutral position near center of range
        let cal_alpha = 0.01;  // Slow center tracking
        let center_x = (self.observed_x_min + self.observed_x_max) / 2.0;
        let center_y = (self.observed_y_min + self.observed_y_max) / 2.0;

        // Slowly move center towards current position
        let new_center_x = center_x + (self.ema_nose_x - center_x) * cal_alpha;
        let new_center_y = center_y + (self.ema_nose_y - center_y) * cal_alpha;

        // Expand range if current position is outside
        let half_span_x = (self.observed_x_max - self.observed_x_min) / 2.0;
        let half_span_y = (self.observed_y_max - self.observed_y_min) / 2.0;
        let dist_from_center_x = (self.ema_nose_x - new_center_x).abs();
        let dist_from_center_y = (self.ema_nose_y - new_center_y).abs();

        // Grow span if needed (fast), shrink slowly
        let new_half_span_x = if dist_from_center_x > half_span_x {
            half_span_x + (dist_from_center_x - half_span_x) * 0.1
        } else {
            half_span_x * 0.999  // Very slow shrink
        };
        let new_half_span_y = if dist_from_center_y > half_span_y {
            half_span_y + (dist_from_center_y - half_span_y) * 0.1
        } else {
            half_span_y * 0.999
        };

        // Update observed range
        self.observed_x_min = new_center_x - new_half_span_x;
        self.observed_x_max = new_center_x + new_half_span_x;
        self.observed_y_min = new_center_y - new_half_span_y;
        self.observed_y_max = new_center_y + new_half_span_y;

        // Use observed range with minimum span
        let min_x_span = 0.08;  // Minimum X range for sensitivity
        let min_y_span = 0.05;  // Minimum Y range
        let x_span = (self.observed_x_max - self.observed_x_min).max(min_x_span);
        let y_span = (self.observed_y_max - self.observed_y_min).max(min_y_span);
        let x_center = (self.observed_x_min + self.observed_x_max) / 2.0;
        let y_center = (self.observed_y_min + self.observed_y_max) / 2.0;

        // Normalize to [0, 1] using auto-calibrated range
        let mut h_norm = (self.ema_nose_x - (x_center - x_span / 2.0)) / x_span;
        let mut v_norm = (self.ema_nose_y - (y_center - y_span / 2.0)) / y_span;

        // Apply subtle gain for more responsiveness without over-amplifying edges
        // Using curve that's stronger in center, weaker at edges
        let gain = 1.2;
        h_norm = 0.5 + (h_norm - 0.5) * gain;
        v_norm = 0.5 + (v_norm - 0.5) * gain;

        // Apply center deadzone (reduced for more sensitivity)
        let deadzone = 0.03;
        if (h_norm - 0.5).abs() < deadzone {
            h_norm = 0.5;
        }
        if (v_norm - 0.5).abs() < deadzone {
            v_norm = 0.5;
        }

        // Clamp to [0, 1]
        h_norm = h_norm.clamp(0.0, 1.0);
        v_norm = v_norm.clamp(0.0, 1.0);

        // Convert to screen coordinates
        let target_x = h_norm * self.screen_width;
        let target_y = v_norm * self.screen_height;

        // Distance-based adaptive smoothing
        let dx = target_x - self.ema_x;
        let dy = target_y - self.ema_y;
        let dist = (dx * dx + dy * dy).sqrt();

        if dist > 8.0 {
            self.ema_x += dx * 0.35;
            self.ema_y += dy * 0.35;
        } else {
            self.ema_x = target_x;
            self.ema_y = target_y;
        }

        // Log periodically
        if self.frame_count % 60 == 0 {
            log(&format!("🎯 Raw({:.4}, {:.4}) EMA({:.4}, {:.4}) AutoCal({:.2}-{:.2}, {:.2}-{:.2}) Norm({:.3}, {:.3}) Scr({:.0}, {:.0})",
                nose_x, nose_y, self.ema_nose_x, self.ema_nose_y,
                self.observed_x_min, self.observed_x_max, self.observed_y_min, self.observed_y_max,
                h_norm, v_norm, self.ema_x, self.ema_y));
        }

        GazeResult::gaze(self.ema_x, self.ema_y)
    }

    fn stop(&mut self) {
        self.status = TrackerStatus::Stopped;
        self.python_face_mesh = None;
        log("🛑 Tracker stopped");
    }
}

// ============================================================================
// C FFI Interface
// ============================================================================

#[no_mangle]
pub extern "C" fn iris_gaze_init(
    screen_width: i32,
    screen_height: i32,
    _dominant_eye: *const c_char,
) -> *mut GazeTracker {
    log(&format!("🦀 iris_gaze_init({}x{}) GazeResult size={}",
        screen_width, screen_height, std::mem::size_of::<GazeResult>()));

    let mut tracker = Box::new(GazeTracker::new(screen_width, screen_height));

    if let Err(e) = tracker.initialize() {
        log(&format!("❌ Init failed: {:?}", e));
        return ptr::null_mut();
    }

    Box::into_raw(tracker)
}

#[no_mangle]
pub extern "C" fn iris_gaze_get_frame(tracker: *mut GazeTracker) -> GazeResult {
    if tracker.is_null() {
        return GazeResult::invalid();
    }
    let tracker = unsafe { &mut *tracker };
    let result = tracker.process_frame();

    result
}

#[no_mangle]
pub extern "C" fn iris_gaze_get_status(tracker: *const GazeTracker) -> TrackerStatus {
    if tracker.is_null() {
        return TrackerStatus::Uninitialized;
    }
    let tracker = unsafe { &*tracker };
    tracker.status
}

#[no_mangle]
pub extern "C" fn iris_gaze_get_error(_tracker: *const GazeTracker) -> GazeError {
    GazeError::None
}

#[no_mangle]
pub extern "C" fn iris_gaze_stop(tracker: *mut GazeTracker) {
    if tracker.is_null() {
        return;
    }
    let tracker = unsafe { &mut *tracker };
    tracker.stop();
}

#[no_mangle]
pub extern "C" fn iris_gaze_destroy(tracker: *mut GazeTracker) {
    if !tracker.is_null() {
        let _ = unsafe { Box::from_raw(tracker) };
        log("🗑️ Tracker destroyed");
    }
}

#[no_mangle]
pub extern "C" fn iris_gaze_set_screen_size(tracker: *mut GazeTracker, width: i32, height: i32) {
    if tracker.is_null() {
        return;
    }
    let tracker = unsafe { &mut *tracker };
    tracker.screen_width = width as f64;
    tracker.screen_height = height as f64;
}

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
    tracker.nose_x_min = x_min;
    tracker.nose_x_max = x_max;
    tracker.nose_y_min = y_min;
    tracker.nose_y_max = y_max;
    log(&format!("🎯 Calibration set: X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}]", x_min, x_max, y_min, y_max));
}

#[no_mangle]
pub extern "C" fn iris_gaze_set_reach_gain(_tracker: *mut GazeTracker, _gain_x: f64, _gain_y: f64) {
    // Not used in Python-equivalent implementation
}

#[no_mangle]
pub extern "C" fn iris_gaze_get_raw_position(
    _tracker: *mut GazeTracker,
    _nose_x: *mut f64,
    _nose_y: *mut f64,
) -> bool {
    false
}

#[no_mangle]
pub extern "C" fn iris_gaze_set_auto_calibrate(_tracker: *mut GazeTracker, _enabled: bool) {
    // Not used in Python-equivalent implementation
}
