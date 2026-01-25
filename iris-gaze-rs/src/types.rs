//! Shared types for the IRIS gaze tracking library
//!
//! These types are exposed via C FFI and used throughout the crate.

/// Result of a single gaze tracking frame
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct GazeResult {
    /// X coordinate on screen (0 to screen_width)
    pub x: f64,
    /// Y coordinate on screen (0 to screen_height)
    pub y: f64,
    /// Event type: 0=none, 1=gaze, 2=blink/wink
    pub event_type: u8,
    /// Blink eye: 0=none, 1=left, 2=right, 3=both
    pub blink_eye: u8,
    /// Whether this result is valid
    pub valid: bool,
}

impl Default for GazeResult {
    fn default() -> Self {
        Self {
            x: 0.0,
            y: 0.0,
            event_type: 0,
            blink_eye: 0,
            valid: false,
        }
    }
}

impl GazeResult {
    /// Create a gaze event result
    pub fn gaze(x: f64, y: f64) -> Self {
        Self {
            x,
            y,
            event_type: 1,
            blink_eye: 0,
            valid: true,
        }
    }

    /// Create a blink/wink event result
    pub fn blink(x: f64, y: f64, blink_eye: u8) -> Self {
        Self {
            x,
            y,
            event_type: 2,
            blink_eye,
            valid: true,
        }
    }

    /// Create an invalid/no-data result
    pub fn invalid() -> Self {
        Self::default()
    }
}

/// Configuration for the gaze tracker
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct GazeConfig {
    /// Screen width in pixels
    pub screen_width: i32,
    /// Screen height in pixels
    pub screen_height: i32,
    /// Camera frame width
    pub camera_width: i32,
    /// Camera frame height
    pub camera_height: i32,
    /// Target FPS for camera capture
    pub target_fps: i32,
    /// EMA smoothing factor (0.0 to 1.0)
    pub ema_alpha: f32,
    /// Deadzone around center (0.0 to 0.5)
    pub deadzone: f32,
    /// Eye aspect ratio threshold for blink detection
    pub blink_threshold: f32,
    /// Number of consecutive frames for wink detection
    pub wink_frames: i32,
}

impl Default for GazeConfig {
    fn default() -> Self {
        Self {
            screen_width: 1920,
            screen_height: 1080,
            camera_width: 640,
            camera_height: 480,
            target_fps: 30,
            ema_alpha: 0.25,
            deadzone: 0.08,
            blink_threshold: 0.25,
            wink_frames: 8,
        }
    }
}

/// Which eye is dominant for tracking
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DominantEye {
    Left = 0,
    Right = 1,
}

impl From<&str> for DominantEye {
    fn from(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "right" => DominantEye::Right,
            _ => DominantEye::Left,
        }
    }
}

/// Status of the gaze tracker
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrackerStatus {
    /// Tracker is not initialized
    Uninitialized = 0,
    /// Tracker is initializing (loading model, opening camera)
    Initializing = 1,
    /// Tracker is running and producing gaze data
    Running = 2,
    /// Tracker is paused
    Paused = 3,
    /// Tracker encountered an error
    Error = 4,
    /// Tracker is stopped
    Stopped = 5,
}

/// Error codes returned by the library
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GazeError {
    /// No error
    None = 0,
    /// Camera not found or failed to open
    CameraError = 1,
    /// Failed to load ML model
    ModelError = 2,
    /// No face detected in frame
    NoFaceDetected = 3,
    /// Invalid configuration
    InvalidConfig = 4,
    /// Internal error
    InternalError = 5,
    /// Tracker not initialized
    NotInitialized = 6,
}

/// 2D point for landmark positions
#[derive(Debug, Clone, Copy, Default)]
pub struct Point2D {
    pub x: f32,
    pub y: f32,
}

impl Point2D {
    pub fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }
}

/// 3D point for landmark positions with depth
#[derive(Debug, Clone, Copy, Default)]
pub struct Point3D {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

impl Point3D {
    pub fn new(x: f32, y: f32, z: f32) -> Self {
        Self { x, y, z }
    }

    /// Convert to 2D by dropping z coordinate
    pub fn to_2d(&self) -> Point2D {
        Point2D::new(self.x, self.y)
    }
}

/// Facial landmarks for gaze tracking
/// Based on MediaPipe face mesh landmark indices
#[derive(Debug, Clone, Default)]
pub struct FaceLandmarks {
    /// All 468 landmarks (x, y, z normalized 0-1)
    pub landmarks: Vec<Point3D>,
}

impl FaceLandmarks {
    /// Create from vector of landmarks
    pub fn new(landmarks: Vec<Point3D>) -> Self {
        Self { landmarks }
    }

    /// MediaPipe landmark indices
    pub const NOSE_TIP: usize = 4;
    pub const FOREHEAD: usize = 10;

    // Left eye landmarks
    pub const LEFT_EYE_TOP: usize = 159;
    pub const LEFT_EYE_BOTTOM: usize = 145;
    pub const LEFT_EYE_LEFT: usize = 33;
    pub const LEFT_EYE_RIGHT: usize = 133;

    // Right eye landmarks
    pub const RIGHT_EYE_TOP: usize = 386;
    pub const RIGHT_EYE_BOTTOM: usize = 374;
    pub const RIGHT_EYE_LEFT: usize = 362;
    pub const RIGHT_EYE_RIGHT: usize = 263;

    /// Get landmark by index
    pub fn get(&self, index: usize) -> Option<&Point3D> {
        self.landmarks.get(index)
    }

    /// Get nose tip position for horizontal tracking
    pub fn nose_tip(&self) -> Option<Point3D> {
        self.landmarks.get(Self::NOSE_TIP).copied()
    }

    /// Get forehead position for vertical tracking
    pub fn forehead(&self) -> Option<Point3D> {
        self.landmarks.get(Self::FOREHEAD).copied()
    }

    /// Calculate eye aspect ratio for left eye
    pub fn left_eye_aspect_ratio(&self) -> Option<f32> {
        let top = self.landmarks.get(Self::LEFT_EYE_TOP)?;
        let bottom = self.landmarks.get(Self::LEFT_EYE_BOTTOM)?;
        let left = self.landmarks.get(Self::LEFT_EYE_LEFT)?;
        let right = self.landmarks.get(Self::LEFT_EYE_RIGHT)?;

        let vertical = (top.y - bottom.y).abs();
        let horizontal = (right.x - left.x).abs();

        if horizontal > 0.0 {
            Some(vertical / horizontal)
        } else {
            None
        }
    }

    /// Calculate eye aspect ratio for right eye
    pub fn right_eye_aspect_ratio(&self) -> Option<f32> {
        let top = self.landmarks.get(Self::RIGHT_EYE_TOP)?;
        let bottom = self.landmarks.get(Self::RIGHT_EYE_BOTTOM)?;
        let left = self.landmarks.get(Self::RIGHT_EYE_LEFT)?;
        let right = self.landmarks.get(Self::RIGHT_EYE_RIGHT)?;

        let vertical = (top.y - bottom.y).abs();
        let horizontal = (right.x - left.x).abs();

        if horizontal > 0.0 {
            Some(vertical / horizontal)
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gaze_result_default() {
        let result = GazeResult::default();
        assert!(!result.valid);
        assert_eq!(result.event_type, 0);
    }

    #[test]
    fn test_gaze_result_gaze() {
        let result = GazeResult::gaze(100.0, 200.0);
        assert!(result.valid);
        assert_eq!(result.event_type, 1);
        assert_eq!(result.x, 100.0);
        assert_eq!(result.y, 200.0);
    }

    #[test]
    fn test_gaze_result_blink() {
        let result = GazeResult::blink(150.0, 250.0, 2);
        assert!(result.valid);
        assert_eq!(result.event_type, 2);
        assert_eq!(result.blink_eye, 2);
    }

    #[test]
    fn test_dominant_eye_from_str() {
        assert_eq!(DominantEye::from("left"), DominantEye::Left);
        assert_eq!(DominantEye::from("right"), DominantEye::Right);
        assert_eq!(DominantEye::from("LEFT"), DominantEye::Left);
        assert_eq!(DominantEye::from("RIGHT"), DominantEye::Right);
        assert_eq!(DominantEye::from("unknown"), DominantEye::Left);
    }
}
