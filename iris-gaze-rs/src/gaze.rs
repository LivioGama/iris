//! Gaze estimation module
//!
//! Converts facial landmarks to screen coordinates using head pose tracking.
//! Uses One Euro Filter for smooth, low-latency tracking.

use crate::types::FaceLandmarks;
use std::time::Instant;

/// One Euro Filter for smooth, low-latency signal filtering
/// Reference: https://cristal.univ-lille.fr/~casiez/1euro/
struct OneEuroFilter {
    // Filter parameters
    min_cutoff: f64, // Minimum cutoff frequency (Hz) - lower = smoother
    beta: f64,       // Speed coefficient - higher = less lag when moving fast
    d_cutoff: f64,   // Derivative cutoff frequency

    // Filter state
    x_prev: f64,
    dx_prev: f64,
    last_time: Option<Instant>,
    initialized: bool,
}

impl OneEuroFilter {
    fn new(min_cutoff: f64, beta: f64) -> Self {
        Self {
            min_cutoff,
            beta,
            d_cutoff: 1.0,
            x_prev: 0.0,
            dx_prev: 0.0,
            last_time: None,
            initialized: false,
        }
    }

    fn smoothing_factor(te: f64, cutoff: f64) -> f64 {
        let tau = 1.0 / (2.0 * std::f64::consts::PI * cutoff);
        1.0 / (1.0 + tau / te)
    }

    fn exponential_smoothing(a: f64, x: f64, x_prev: f64) -> f64 {
        a * x + (1.0 - a) * x_prev
    }

    fn filter(&mut self, x: f64) -> f64 {
        let now = Instant::now();

        if !self.initialized {
            self.x_prev = x;
            self.dx_prev = 0.0;
            self.last_time = Some(now);
            self.initialized = true;
            return x;
        }

        let te = match self.last_time {
            Some(last) => now.duration_since(last).as_secs_f64().max(0.001),
            None => 1.0 / 60.0, // Assume 60 FPS
        };
        self.last_time = Some(now);

        // Estimate derivative
        let a_d = Self::smoothing_factor(te, self.d_cutoff);
        let dx = (x - self.x_prev) / te;
        let dx_hat = Self::exponential_smoothing(a_d, dx, self.dx_prev);

        // Adaptive cutoff based on speed
        let cutoff = self.min_cutoff + self.beta * dx_hat.abs();

        // Filter the signal
        let a = Self::smoothing_factor(te, cutoff);
        let x_hat = Self::exponential_smoothing(a, x, self.x_prev);

        // Store for next iteration
        self.x_prev = x_hat;
        self.dx_prev = dx_hat;

        x_hat
    }

    fn reset(&mut self, value: f64) {
        self.x_prev = value;
        self.dx_prev = 0.0;
        self.last_time = None;
        self.initialized = false;
    }
}

/// Gaze estimator that converts landmarks to screen coordinates
pub struct GazeEstimator {
    // Screen dimensions
    screen_width: i32,
    screen_height: i32,

    // One Euro Filters for smooth tracking
    filter_x: OneEuroFilter,
    filter_y: OneEuroFilter,

    // Raw nose position filter (before mapping)
    filter_nose_x: OneEuroFilter,
    filter_nose_y: OneEuroFilter,

    // Current smoothed position
    current_x: f64,
    current_y: f64,

    // Deadzone parameters
    deadzone: f32,

    // Range expansion to reach screen corners more easily
    reach_gain_x: f64,
    reach_gain_y: f64,

    // Velocity tracking for adaptive smoothing
    last_raw_x: f64,
    last_raw_y: f64,
    velocity_x: f64,
    velocity_y: f64,
    raw_prev_x: f64,
    raw_prev_y: f64,
    raw_prev_valid: bool,

    // Calibration ranges (based on measured values from Python)
    nose_x_min: f64,
    nose_x_max: f64,
    nose_y_min: f64,
    nose_y_max: f64,

    // Frame counter for stability
    frames_stable: u32,

    // Auto-calibration mode
    auto_calibrate: bool,
    auto_cal_samples: u32,
    auto_cal_x_min: f64,
    auto_cal_x_max: f64,
    auto_cal_y_min: f64,
    auto_cal_y_max: f64,
}

impl GazeEstimator {
    /// Try to load calibration from /tmp/iris_calibration.txt
    pub fn load_calibration_file() -> Option<(f64, f64, f64, f64)> {
        let content = std::fs::read_to_string("/tmp/iris_calibration.txt").ok()?;
        let mut x_min = None;
        let mut x_max = None;
        let mut y_min = None;
        let mut y_max = None;

        for line in content.lines() {
            if line.starts_with("nose_x_min, nose_x_max =") {
                if let Some(val_part) = line.split('=').nth(1) {
                    let parts: Vec<&str> = val_part.split(',').collect();
                    if parts.len() == 2 {
                        x_min = parts[0].trim().parse().ok();
                        x_max = parts[1].trim().parse().ok();
                    }
                }
            } else if line.starts_with("nose_y_min, nose_y_max =") {
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
            (Some(xmin), Some(xmax), Some(ymin), Some(ymax)) => {
                if let Ok(mut f) = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open("/tmp/iris_rust.log")
                {
                    use std::io::Write;
                    let _ = writeln!(
                        f,
                        "📊 Loaded calibration: x={:.4}-{:.4}, y={:.4}-{:.4}",
                        xmin, xmax, ymin, ymax
                    );
                }
                Some((xmin, xmax, ymin, ymax))
            }
            _ => None,
        }
    }

    /// Try to load reach gain from /tmp/iris_gain.txt
    /// Supported formats:
    ///   reach_gain = 1.4
    ///   reach_gain_x = 1.4
    ///   reach_gain_y = 1.3
    ///   gain = 1.4
    pub fn load_reach_gain_file() -> Option<(f64, f64)> {
        let content = std::fs::read_to_string("/tmp/iris_gain.txt").ok()?;
        let mut gain: Option<f64> = None;
        let mut gain_x: Option<f64> = None;
        let mut gain_y: Option<f64> = None;

        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            let mut parts = line.split('=');
            let key = match parts.next() {
                Some(k) => k.trim(),
                None => continue,
            };
            let value = match parts.next() {
                Some(v) => v.trim().parse::<f64>().ok(),
                None => None,
            };
            if value.is_none() {
                continue;
            }
            let value = value?;
            match key {
                "reach_gain" | "gain" => gain = Some(value),
                "reach_gain_x" => gain_x = Some(value),
                "reach_gain_y" => gain_y = Some(value),
                _ => {}
            }
        }

        if gain_x.is_none() && gain_y.is_none() && gain.is_none() {
            return None;
        }

        let base = gain.unwrap_or(1.0);
        Some((gain_x.unwrap_or(base), gain_y.unwrap_or(base)))
    }

    /// Update reach gain
    pub fn set_reach_gain(&mut self, gain_x: f64, gain_y: f64) {
        self.reach_gain_x = gain_x;
        self.reach_gain_y = gain_y;
    }

    /// Create a new gaze estimator
    pub fn new(screen_width: i32, screen_height: i32, _ema_alpha: f32, deadzone: f32) -> Self {
        let center_x = screen_width as f64 / 2.0;
        let center_y = screen_height as f64 / 2.0;

        // One Euro Filter parameters tuned for gaze tracking:
        // - min_cutoff: Higher = more responsive, lower = smoother
        // - beta: Higher = less lag when moving fast
        let min_cutoff = 3.5; // Increased from 1.8 - more responsive
        let beta = 1.2; // Increased from 0.7 - better speed adaptation

        let mut estimator = Self {
            screen_width,
            screen_height,
            filter_x: OneEuroFilter::new(min_cutoff, beta),
            filter_y: OneEuroFilter::new(min_cutoff, beta),
            filter_nose_x: OneEuroFilter::new(2.5, 0.4), // Smooth raw input
            filter_nose_y: OneEuroFilter::new(2.5, 0.4),
            current_x: center_x,
            current_y: center_y,
            deadzone,
            reach_gain_x: 1.0,
            reach_gain_y: 1.0,
            last_raw_x: 0.5,
            last_raw_y: 0.5,
            velocity_x: 0.0,
            velocity_y: 0.0,
            raw_prev_x: 0.0,
            raw_prev_y: 0.0,
            raw_prev_valid: false,
            // Defaults match the Python tracker baseline.
            // These may be overridden by /tmp/iris_calibration.txt or auto-calibration.
            nose_x_min: 0.5174,
            nose_x_max: 0.5967,
            nose_y_min: 0.3542,
            nose_y_max: 0.3910,
            frames_stable: 0,
            // Auto-calibration disabled - using fixed calibration
            auto_calibrate: false,
            auto_cal_samples: 0,
            auto_cal_x_min: 1.0,
            auto_cal_x_max: 0.0,
            auto_cal_y_min: 1.0,
            auto_cal_y_max: 0.0,
        };

        if let Ok(mut f) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open("/tmp/iris_rust.log")
        {
            use std::io::Write;
            let _ = writeln!(
                f,
                "🔧 GazeEstimator defaults: X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}]. Auto-calibration disabled (may be enabled later).",
                estimator.nose_x_min, estimator.nose_x_max, estimator.nose_y_min, estimator.nose_y_max
            );
        }

        estimator
    }

    /// Estimate gaze position from landmarks
    /// This matches the Python implementation exactly for consistent behavior
    pub fn estimate(&mut self, landmarks: &FaceLandmarks) -> Option<(f64, f64)> {
        static mut FRAME_LOG_COUNTER: u32 = 0;
        let frame_id = unsafe {
            FRAME_LOG_COUNTER += 1;
            FRAME_LOG_COUNTER
        };

        // Get nose tip for horizontal tracking
        let nose = landmarks.nose_tip()?;
        let forehead = landmarks.forehead()?;

        // Use nose.x for horizontal (left/right head turn)
        // Use forehead.y for vertical (same as Python calibration)
        let raw_nose_x = nose.x as f64;
        let raw_nose_y = forehead.y as f64;

        let gain_avg = (self.reach_gain_x + self.reach_gain_y) * 0.5;

        // Reject outliers to avoid sudden jumps (no update if input is unstable)
        let out_of_bounds =
            raw_nose_x < 0.05 || raw_nose_x > 0.95 || raw_nose_y < 0.05 || raw_nose_y > 0.95;
        if out_of_bounds {
            return Some((self.current_x, self.current_y));
        }

        if self.raw_prev_valid {
            let jump_threshold_x = if gain_avg >= 2.0 { 0.05 } else { 0.08 };
            let jump_threshold_y = if gain_avg >= 2.0 { 0.04 } else { 0.06 };
            let dx = (raw_nose_x - self.raw_prev_x).abs();
            let dy = (raw_nose_y - self.raw_prev_y).abs();
            if dx > jump_threshold_x || dy > jump_threshold_y {
                return Some((self.current_x, self.current_y));
            }
        }

        self.raw_prev_x = raw_nose_x;
        self.raw_prev_y = raw_nose_y;
        self.raw_prev_valid = true;

        // Auto-calibration: learn the user's actual range of motion
        if self.auto_calibrate {
            // Only update if values are reasonable (allow wider range for different setups)
            if raw_nose_x > 0.1 && raw_nose_x < 0.95 && raw_nose_y > 0.1 && raw_nose_y < 0.9 {
                self.auto_cal_samples += 1;

                // Track min/max
                if raw_nose_x < self.auto_cal_x_min {
                    self.auto_cal_x_min = raw_nose_x;
                }
                if raw_nose_x > self.auto_cal_x_max {
                    self.auto_cal_x_max = raw_nose_x;
                }
                if raw_nose_y < self.auto_cal_y_min {
                    self.auto_cal_y_min = raw_nose_y;
                }
                if raw_nose_y > self.auto_cal_y_max {
                    self.auto_cal_y_max = raw_nose_y;
                }

                // After collecting enough samples, update calibration with padding
                if self.auto_cal_samples >= 30 {
                    let x_range = self.auto_cal_x_max - self.auto_cal_x_min;
                    let y_range = self.auto_cal_y_max - self.auto_cal_y_min;

                    // Only apply if we have a reasonable range
                    if x_range > 0.02 && y_range > 0.015 {
                        // Add 30% padding for easier corner access
                        let x_pad = x_range * 0.30;
                        let y_pad = y_range * 0.30;

                        self.nose_x_min = self.auto_cal_x_min - x_pad;
                        self.nose_x_max = self.auto_cal_x_max + x_pad;
                        self.nose_y_min = self.auto_cal_y_min - y_pad;
                        self.nose_y_max = self.auto_cal_y_max + y_pad;

                        // Log once when threshold reached
                        if self.auto_cal_samples == 30 {
                            if let Ok(mut f) = std::fs::OpenOptions::new()
                                .create(true)
                                .append(true)
                                .open("/tmp/iris_rust.log")
                            {
                                use std::io::Write;
                                let _ = writeln!(
                                    f,
                                    "🔧 Auto-calibrated: X=[{:.4}, {:.4}], Y=[{:.4}, {:.4}] (range: {:.4}x{:.4})",
                                    self.nose_x_min, self.nose_x_max, self.nose_y_min, self.nose_y_max, x_range, y_range
                                );
                            }
                        }
                    }
                }
            }
        }

        // Refresh reach gain periodically for live tuning
        if frame_id % 60 == 0 {
            if let Some((gain_x, gain_y)) = Self::load_reach_gain_file() {
                if (gain_x - self.reach_gain_x).abs() > 0.001
                    || (gain_y - self.reach_gain_y).abs() > 0.001
                {
                    self.reach_gain_x = gain_x;
                    self.reach_gain_y = gain_y;
                    if let Ok(mut f) = std::fs::OpenOptions::new()
                        .create(true)
                        .append(true)
                        .open("/tmp/iris_rust.log")
                    {
                        use std::io::Write;
                        let _ = writeln!(
                            f,
                            "🎛 Reach gain updated: x={:.2}, y={:.2}",
                            self.reach_gain_x, self.reach_gain_y
                        );
                    }
                }
            }
        }

        // ===== MATCH PYTHON EXACTLY (with adaptive stability) =====
        // Python: ema_nose_x += (nose_x - ema_nose_x) * 0.25
        // EMA smoothing on raw nose position BEFORE normalizing
        // Increased alpha for more responsiveness (was 0.15-0.25)
        let raw_alpha = if gain_avg >= 3.0 {
            0.35 // Increased from 0.15
        } else if gain_avg >= 2.5 {
            0.45 // Increased from 0.20
        } else {
            0.55 // Increased from 0.25
        };
        self.last_raw_x += (raw_nose_x - self.last_raw_x) * raw_alpha;
        self.last_raw_y += (raw_nose_y - self.last_raw_y) * raw_alpha;

        let ema_nose_x = self.last_raw_x;
        let ema_nose_y = self.last_raw_y;

        // Normalize using EMA'd values (like Python)
        // INVERT horizontal: when you look right, nose moves left in camera, so we flip it
        let mut h_norm =
            1.0 - ((ema_nose_x - self.nose_x_min) / (self.nose_x_max - self.nose_x_min));
        let mut v_norm = (ema_nose_y - self.nose_y_min) / (self.nose_y_max - self.nose_y_min);

        // Apply deadzone to normalized coordinates (reduced for more responsiveness)
        let deadzone = if gain_avg >= 3.0 {
            0.10 // Reduced from 0.16
        } else if gain_avg >= 2.5 {
            0.08 // Reduced from 0.12
        } else {
            self.deadzone as f64 * 0.7 // Reduced by 30%
        };
        if (h_norm - 0.5).abs() < deadzone {
            h_norm = 0.5;
        }
        if (v_norm - 0.5).abs() < deadzone {
            v_norm = 0.5;
        }

        // Expand range around center so corners are easier to reach
        h_norm = 0.5 + (h_norm - 0.5) * self.reach_gain_x;
        v_norm = 0.5 + (v_norm - 0.5) * self.reach_gain_y;

        // Clamp to [0, 1]
        let h_clamped = h_norm.clamp(0.0, 1.0);
        let v_clamped = v_norm.clamp(0.0, 1.0);

        // Convert to screen coordinates
        let target_x = h_clamped * self.screen_width as f64;
        let target_y = v_clamped * self.screen_height as f64;

        // Extra smoothing for amplified reach to prevent jitter (increased responsiveness)
        let response = if gain_avg >= 3.0 {
            0.32 // Increased from 0.18
        } else if gain_avg >= 2.5 {
            0.40 // Increased from 0.22
        } else if gain_avg >= 2.0 {
            0.50 // Increased from 0.30
        } else {
            0.60 // Increased from 0.35
        };
        let snap_threshold = if gain_avg >= 3.0 {
            12.0 // Reduced from 20.0 - snap sooner
        } else if gain_avg >= 2.5 {
            10.0 // Reduced from 16.0
        } else {
            6.0 // Reduced from 8.0
        };

        // Python's distance-based adaptive smoothing:
        // dx = target_x - ema_x; dy = target_y - ema_y
        // dist = sqrt(dx*dx + dy*dy)
        // if dist > 8: ema += d * 0.35  else: ema = target
        let dx = target_x - self.current_x;
        let dy = target_y - self.current_y;
        let dist = (dx * dx + dy * dy).sqrt();

        if dist > snap_threshold {
            self.current_x += dx * response;
            self.current_y += dy * response;
        } else {
            self.current_x = target_x;
            self.current_y = target_y;
        }

        // Log tracking details every 10 frames
        if frame_id % 10 == 0 {
            if let Ok(mut f) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_rust_gaze.log")
            {
                use std::io::Write;
                let _ = writeln!(
                    f,
                    "Frame {}: raw=({:.4},{:.4}) ema=({:.4},{:.4}) norm=({:.4},{:.4}) calib_x=({:.4}-{:.4}) calib_y=({:.4}-{:.4})",
                    frame_id, raw_nose_x, raw_nose_y, ema_nose_x, ema_nose_y, h_norm, v_norm, self.nose_x_min, self.nose_x_max, self.nose_y_min, self.nose_y_max
                );
            }
        }

        // Detailed periodic logging to /tmp/iris_rust.log
        if frame_id % 60 == 0 {
            if let Ok(mut f) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_rust.log")
            {
                use std::io::Write;
                let _ = writeln!(
                    f,
                    "🎯 Gaze [{}]: Nose({:.4}, {:.4}) -> Norm({:.3}, {:.3}) -> Screen({:.0}, {:.0})",
                    frame_id, raw_nose_x, raw_nose_y, h_clamped, v_clamped, self.current_x, self.current_y
                );
            }
        }

        Some((self.current_x, self.current_y))
    }

    /// Get current smoothed position without updating
    pub fn get_current_position(&self) -> (f64, f64) {
        (self.current_x, self.current_y)
    }

    /// Update screen dimensions
    pub fn set_screen_size(&mut self, width: i32, height: i32) {
        let scale_x = width as f64 / self.screen_width as f64;
        let scale_y = height as f64 / self.screen_height as f64;

        self.current_x *= scale_x;
        self.current_y *= scale_y;

        self.screen_width = width;
        self.screen_height = height;

        // Reset filters with new center
        let center_x = width as f64 / 2.0;
        let center_y = height as f64 / 2.0;
        self.filter_x.reset(center_x);
        self.filter_y.reset(center_y);
    }

    /// Update calibration ranges
    pub fn set_calibration(&mut self, x_min: f64, x_max: f64, y_min: f64, y_max: f64) {
        self.nose_x_min = x_min;
        self.nose_x_max = x_max;
        self.nose_y_min = y_min;
        self.nose_y_max = y_max;
        // Disable auto-calibration when manual calibration is set
        self.auto_calibrate = false;
    }

    /// Enable or disable auto-calibration mode
    pub fn set_auto_calibrate(&mut self, enabled: bool) {
        self.auto_calibrate = enabled;
        if enabled {
            // Reset auto-calibration tracking
            self.auto_cal_samples = 0;
            self.auto_cal_x_min = 1.0;
            self.auto_cal_x_max = 0.0;
            self.auto_cal_y_min = 1.0;
            self.auto_cal_y_max = 0.0;
        }
    }

    /// Reset position to screen center
    pub fn reset(&mut self) {
        let center_x = self.screen_width as f64 / 2.0;
        let center_y = self.screen_height as f64 / 2.0;

        self.current_x = center_x;
        self.current_y = center_y;
        self.filter_x.reset(center_x);
        self.filter_y.reset(center_y);
        self.filter_nose_x.reset(0.5);
        self.filter_nose_y.reset(0.5);
        self.last_raw_x = 0.5;
        self.last_raw_y = 0.5;
        self.velocity_x = 0.0;
        self.velocity_y = 0.0;
        self.raw_prev_valid = false;
        self.frames_stable = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Point3D;

    fn create_test_landmarks(nose_x: f32, forehead_y: f32) -> FaceLandmarks {
        let mut landmarks = vec![Point3D::default(); 468];
        landmarks[FaceLandmarks::NOSE_TIP] = Point3D::new(nose_x, 0.37, 0.0);
        landmarks[FaceLandmarks::FOREHEAD] = Point3D::new(0.5, forehead_y, 0.0);
        FaceLandmarks { landmarks }
    }

    #[test]
    fn test_one_euro_filter() {
        let mut filter = OneEuroFilter::new(1.0, 0.5);

        // Should converge to stable value
        for _ in 0..20 {
            let result = filter.filter(100.0);
            assert!(result > 0.0);
        }

        let final_val = filter.filter(100.0);
        assert!((final_val - 100.0).abs() < 1.0);
    }

    #[test]
    fn test_gaze_estimator_smooth() {
        let mut estimator = GazeEstimator::new(1920, 1080, 0.25, 0.05);

        // Simulate stable gaze at center
        let landmarks = create_test_landmarks(0.55, 0.37);

        let mut positions = Vec::new();
        for _ in 0..30 {
            if let Some((x, y)) = estimator.estimate(&landmarks) {
                positions.push((x, y));
            }
        }

        // Check that positions converge (low variance after initial frames)
        if positions.len() > 10 {
            let last_10: Vec<_> = positions.iter().skip(positions.len() - 10).collect();
            let avg_x: f64 = last_10.iter().map(|(x, _)| x).sum::<f64>() / 10.0;

            for (x, _) in last_10 {
                assert!((x - avg_x).abs() < 50.0, "Position should be stable");
            }
        }
    }
}
