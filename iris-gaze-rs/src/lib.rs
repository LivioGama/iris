//! IRIS Gaze Tracking Library
//!
//! Native Rust/OpenCV gaze tracking pipeline exposed over C FFI.

pub mod camera;
pub mod face_mesh;
pub mod types;

use std::ffi::c_char;
use std::ptr;
use std::env;
use std::path::Path;

use camera::Camera;
use face_mesh::FaceMeshDetector;
pub use types::*;

fn log(msg: &str) {
    if std::env::var("IRIS_VERBOSE_LOGS").ok().as_deref() != Some("1") {
        return;
    }
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

    // Native camera capture + face mesh detection
    camera: Option<Camera>,
    face_mesh: Option<FaceMeshDetector>,

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

    // Whether a calibration file override is active
    calibration_file_active: bool,

    // Status
    status: TrackerStatus,
    frame_count: u32,
    camera_index: i32,
}

const TMP_CAL_PATH: &str = "/tmp/iris_calibration.txt";
const PERSISTENT_CAL_FILENAME: &str = ".iris_calibration.txt"; // stored in $HOME
const RAW_NOSE_PATH: &str = "/tmp/iris_raw_nose.txt";

fn parse_calibration_file(path: &str) -> Option<(f64, f64, f64, f64)> {
    let content = std::fs::read_to_string(path).ok()?;
    let mut x_min = None;
    let mut x_max = None;
    let mut y_min = None;
    let mut y_max = None;

    for line in content.lines() {
        if line.starts_with("nose_x_min") {
            if let Some(val_part) = line.split('=').nth(1) {
                let parts: Vec<&str> = val_part.split(',').collect();
                if parts.len() == 2 {
                    x_min = parts[0].trim().parse().ok();
                    x_max = parts[1].trim().parse().ok();
                }
            }
        } else if line.starts_with("nose_y_min") {
            if let Some(val_part) = line.split('=').nth(1) {
                let parts: Vec<&str> = val_part.split(',').collect();
                if parts.len() == 2 {
                    y_min = parts[0].trim().parse().ok();
                    y_max = parts[1].trim().parse().ok();
                }
            }
        }
    }

    match (x_min, x_max, y_min, y_max) {
        (Some(xn), Some(xx), Some(yn), Some(yx)) => Some((xn, xx, yn, yx)),
        _ => None,
    }
}

fn load_prioritized_calibration() -> Option<((f64, f64, f64, f64), String)> {
    if let Some(vals) = parse_calibration_file(TMP_CAL_PATH) {
        return Some((vals, TMP_CAL_PATH.to_string()));
    }

    if let Ok(home) = env::var("HOME") {
        let path = format!("{}/{}", home, PERSISTENT_CAL_FILENAME);
        if Path::new(&path).exists() {
            if let Some(vals) = parse_calibration_file(&path) {
                return Some((vals, path));
            }
        }
    }

    None
}

fn seed_from_raw_nose() -> Option<(f64, f64, f64, f64)> {
    let content = std::fs::read_to_string(RAW_NOSE_PATH).ok()?;
    let mut parts = content.split_whitespace();
    let raw_x: f64 = parts.next()?.parse().ok()?;
    let raw_y: f64 = parts.next()?.parse().ok()?;

    // Use generous spans so the user can reach corners without a full calibration run
    let span_x = 0.26; // ~ ±13% around center
    let span_y = 0.18; // ~ ±9% around center

    let half_x = span_x / 2.0;
    let half_y = span_y / 2.0;

    let mut x_min = raw_x - half_x;
    let mut x_max = raw_x + half_x;
    let mut y_min = raw_y - half_y;
    let mut y_max = raw_y + half_y;

    // Keep within sane bounds
    x_min = x_min.clamp(0.05, 0.95);
    x_max = x_max.clamp(0.05, 0.95);
    y_min = y_min.clamp(0.05, 0.95);
    y_max = y_max.clamp(0.05, 0.95);

    // Ensure ordering
    if x_min >= x_max || y_min >= y_max {
        return None;
    }

    Some((x_min, x_max, y_min, y_max))
}

impl GazeTracker {
    fn new(screen_width: i32, screen_height: i32, camera_index: i32) -> Self {
        let sw = screen_width as f64;
        let sh = screen_height as f64;

        Self {
            screen_width: sw,
            screen_height: sh,
            camera: None,
            face_mesh: None,
            ema_x: sw / 2.0,
            ema_y: sh / 2.0,
            ema_nose_x: 0.45, // Will quickly adapt via EMA
            ema_nose_y: 0.42, // Will quickly adapt via EMA
            // Very wide range to handle coordinate variance
            nose_x_min: 0.15,
            nose_x_max: 0.75,
            nose_y_min: 0.30,
            nose_y_max: 0.55,
            // Auto-calibration: start at center, range grows from observed data
            observed_x_min: 0.45,
            observed_x_max: 0.45,
            observed_y_min: 0.42,
            observed_y_max: 0.42,
            calibration_file_active: false,
            status: TrackerStatus::Uninitialized,
            frame_count: 0,
            camera_index,
        }
        .with_calibration_seed()
    }

    /// Apply persisted calibration if available, else seed from latest raw nose sample.
    fn with_calibration_seed(mut self) -> Self {
        // 1) Try loading /tmp/iris_calibration.txt (written by calibrate.py) or fallback in $HOME.
        if let Some(((xn, xx, yn, yx), path)) = load_prioritized_calibration() {
            self.nose_x_min = xn;
            self.nose_x_max = xx;
            self.nose_y_min = yn;
            self.nose_y_max = yx;
            self.observed_x_min = xn;
            self.observed_x_max = xx;
            self.observed_y_min = yn;
            self.observed_y_max = yx;
            self.calibration_file_active = true;

            if let Ok(mut f) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_rust.log")
            {
                use std::io::Write;
                let _ = writeln!(
                    f,
                    "📊 Loaded calibration at startup from {}: X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}]",
                    path, xn, xx, yn, yx
                );
            }

            // If calibration came from $HOME, mirror it to /tmp so runtime reload sees it.
            if path != TMP_CAL_PATH && !Path::new(TMP_CAL_PATH).exists() {
                let _ = std::fs::copy(&path, TMP_CAL_PATH);
            }

            return self;
        }

        // 2) Seed from most recent raw nose sample to give usable defaults without running calibrate.py
        if let Some((xn, xx, yn, yx)) = seed_from_raw_nose() {
            self.nose_x_min = xn;
            self.nose_x_max = xx;
            self.nose_y_min = yn;
            self.nose_y_max = yx;
            self.observed_x_min = xn;
            self.observed_x_max = xx;
            self.observed_y_min = yn;
            self.observed_y_max = yx;

            if let Ok(mut f) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_rust.log")
            {
                use std::io::Write;
                let _ = writeln!(
                    f,
                    "🌱 Seeded calibration from raw nose sample: X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}]",
                    xn, xx, yn, yx
                );
            }

            // Persist seed so subsequent runs pick it up immediately.
            let cal_text = format!(
                "nose_x_min, nose_x_max = {:.6}, {:.6}\nnose_y_min, nose_y_max = {:.6}, {:.6}\n",
                xn, xx, yn, yx
            );
            let _ = std::fs::write(TMP_CAL_PATH, &cal_text);
            if let Ok(home) = env::var("HOME") {
                let home_path = format!("{}/{}", home, PERSISTENT_CAL_FILENAME);
                let _ = std::fs::write(home_path, &cal_text);
            }
        }

        self
    }

    fn initialize(&mut self) -> Result<(), GazeError> {
        log(&format!(
            "🚀 GazeTracker::initialize() - Cal: X={:.2}-{:.2}, Y={:.2}-{:.2}",
            self.nose_x_min, self.nose_x_max, self.nose_y_min, self.nose_y_max
        ));

        self.status = TrackerStatus::Initializing;

        match Camera::new(self.camera_index, 640, 480, 30) {
            Ok(camera) => {
                self.camera = Some(camera);
                log("✅ Camera initialized");
            }
            Err(e) => {
                log(&format!("❌ Camera initialization failed: {:?}", e));
                self.status = TrackerStatus::Error;
                return Err(GazeError::CameraError);
            }
        }

        match FaceMeshDetector::new() {
            Ok(detector) => {
                self.face_mesh = Some(detector);
                log("✅ Face mesh detector initialized");
            }
            Err(e) => {
                log(&format!(
                    "❌ Face mesh detector initialization failed: {:?}",
                    e
                ));
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

        // Get next camera frame.
        let camera = match &mut self.camera {
            Some(c) => c,
            None => return GazeResult::invalid(),
        };
        let frame = match camera.capture_frame() {
            Ok(frame) => frame,
            Err(_) => return GazeResult::invalid(),
        };

        // Detect landmarks on the current frame.
        let face_mesh = match &mut self.face_mesh {
            Some(detector) => detector,
            None => return GazeResult::invalid(),
        };
        let landmarks = match face_mesh.detect(&frame) {
            Ok(Some(lm)) => lm,
            _ => return GazeResult::invalid(),
        };

        // === GAZE TRACKING (matches Python exactly) ===

        // Get nose tip (landmark 4) and forehead (landmark 10)
        let nose = match landmarks.get(4) {
            Some(p) => p,
            None => return GazeResult::invalid(),
        };
        let forehead = match landmarks.get(10) {
            Some(p) => p,
            None => return GazeResult::invalid(),
        };

        let nose_x = nose.x as f64;
        let nose_y = forehead.y as f64; // Use forehead Y for vertical

        // Write raw nose position for calibration tool (atomic overwrite every frame)
        if self.frame_count % 2 == 0 {
            let _ = std::fs::write(
                "/tmp/iris_raw_nose.txt",
                format!("{:.6} {:.6} {:.6} {:.6}\n", nose_x, nose_y, self.ema_nose_x, self.ema_nose_y),
            );
        }

        // EMA smoothing on raw nose position
        // Lower alpha = heavier smoothing = less jitter
        let nose_alpha = 0.12;
        self.ema_nose_x += (nose_x - self.ema_nose_x) * nose_alpha;
        self.ema_nose_y += (nose_y - self.ema_nose_y) * nose_alpha;

        // Load calibration file every 60 frames (~2s). Prefer /tmp, then $HOME/.iris_calibration.txt.
        if self.frame_count % 60 == 0 {
            if let Some(((xn, xx, yn, yx), path)) = load_prioritized_calibration() {
                let changed = !self.calibration_file_active
                    || (xn - self.observed_x_min).abs() > 0.0001
                    || (xx - self.observed_x_max).abs() > 0.0001
                    || (yn - self.observed_y_min).abs() > 0.0001
                    || (yx - self.observed_y_max).abs() > 0.0001;
                if changed {
                    self.observed_x_min = xn;
                    self.observed_x_max = xx;
                    self.observed_y_min = yn;
                    self.observed_y_max = yx;
                    self.calibration_file_active = true;
                    // Always log calibration changes (not gated by IRIS_VERBOSE_LOGS)
                    if let Ok(mut f) = std::fs::OpenOptions::new()
                        .create(true)
                        .append(true)
                        .open("/tmp/iris_rust.log")
                    {
                        use std::io::Write;
                        let _ = writeln!(
                            f,
                            "📊 Loaded calibration file ({}): X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}]",
                            path, xn, xx, yn, yx
                        );
                    }
                }

                // Mirror $HOME calibration into /tmp for consistency if needed.
                if path != TMP_CAL_PATH && !Path::new(TMP_CAL_PATH).exists() {
                    let _ = std::fs::copy(&path, TMP_CAL_PATH);
                }
            } else if self.calibration_file_active {
                // File was deleted — revert to auto-calibration
                self.calibration_file_active = false;
                if let Ok(mut f) = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open("/tmp/iris_rust.log")
                {
                    use std::io::Write;
                    let _ = writeln!(f, "📊 Calibration file removed, reverting to auto-calibration");
                }
            }
        }

        // Auto-calibration: only active when no calibration file is loaded
        if !self.calibration_file_active {
            let cal_alpha = 0.002;
            let center_x = (self.observed_x_min + self.observed_x_max) / 2.0;
            let center_y = (self.observed_y_min + self.observed_y_max) / 2.0;
            let new_center_x = center_x + (self.ema_nose_x - center_x) * cal_alpha;
            let new_center_y = center_y + (self.ema_nose_y - center_y) * cal_alpha;
            let half_span_x = (self.observed_x_max - self.observed_x_min) / 2.0;
            let half_span_y = (self.observed_y_max - self.observed_y_min) / 2.0;
            let dist_from_center_x = (self.ema_nose_x - new_center_x).abs();
            let dist_from_center_y = (self.ema_nose_y - new_center_y).abs();
            let mut new_half_span_x = if dist_from_center_x > half_span_x {
                half_span_x + (dist_from_center_x - half_span_x) * 0.1
            } else {
                half_span_x * 0.99998
            };
            let mut new_half_span_y = if dist_from_center_y > half_span_y {
                half_span_y + (dist_from_center_y - half_span_y) * 0.1
            } else {
                half_span_y * 0.99998
            };
            let min_half_span_x = 0.10;
            let min_half_span_y = 0.08;
            new_half_span_x = new_half_span_x.max(min_half_span_x);
            new_half_span_y = new_half_span_y.max(min_half_span_y);
            self.observed_x_min = new_center_x - new_half_span_x;
            self.observed_x_max = new_center_x + new_half_span_x;
            self.observed_y_min = new_center_y - new_half_span_y;
            self.observed_y_max = new_center_y + new_half_span_y;
        }

        // Use observed range
        let x_span = self.observed_x_max - self.observed_x_min;
        let y_span = self.observed_y_max - self.observed_y_min;
        let x_center = (self.observed_x_min + self.observed_x_max) / 2.0;
        let y_center = (self.observed_y_min + self.observed_y_max) / 2.0;

        // Normalize to [0, 1] using auto-calibrated range
        let mut h_norm = (self.ema_nose_x - (x_center - x_span / 2.0)) / x_span;
        let mut v_norm = (self.ema_nose_y - (y_center - y_span / 2.0)) / y_span;

        // Apply gain for responsiveness - but not too high or it amplifies jitter
        let gain = 1.3;
        h_norm = 0.5 + (h_norm - 0.5) * gain;
        v_norm = 0.5 + (v_norm - 0.5) * gain;

        // Apply center deadzone (reduced for more sensitivity)
        let deadzone = 0.01;
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
        // Small movements get heavy smoothing (jitter), large movements respond faster (saccades)
        let dx = target_x - self.ema_x;
        let dy = target_y - self.ema_y;
        let dist = (dx * dx + dy * dy).sqrt();

        let alpha = if dist > 150.0 {
            0.5 // Fast saccade - catch up quickly
        } else if dist > 50.0 {
            0.2 // Medium movement
        } else {
            0.08 // Small movement / jitter - heavy smoothing
        };
        self.ema_x += dx * alpha;
        self.ema_y += dy * alpha;

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
        self.face_mesh = None;
        self.camera = None;
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
    camera_index: i32,
    _dominant_eye: *const c_char,
) -> *mut GazeTracker {
    log(&format!(
        "🦀 iris_gaze_init({}x{}, cam={})",
        screen_width, screen_height, camera_index
    ));

    let mut tracker = Box::new(GazeTracker::new(screen_width, screen_height, camera_index));

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
    log(&format!(
        "🎯 Calibration set: X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}]",
        x_min, x_max, y_min, y_max
    ));
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
