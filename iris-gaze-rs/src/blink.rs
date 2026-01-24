//! Blink and wink detection module
//!
//! Detects eye blinks and winks using Eye Aspect Ratio (EAR).
//! A wink (one eye closed, other open) triggers actions like screenshots.

use crate::types::FaceLandmarks;

/// Result of blink detection
#[derive(Debug, Clone, Copy)]
pub struct BlinkEvent {
    /// True if this is a deliberate wink (one eye closed)
    pub is_wink: bool,
    /// True if left eye is closed
    pub left_closed: bool,
    /// True if right eye is closed
    pub right_closed: bool,
    /// Eye aspect ratio for left eye
    pub left_ear: f32,
    /// Eye aspect ratio for right eye
    pub right_ear: f32,
}

/// Blink and wink detector
///
/// Uses Eye Aspect Ratio (EAR) to detect when eyes are closed.
/// A wink is detected when one eye is closed for multiple consecutive frames
/// while the other eye remains open.
pub struct BlinkDetector {
    /// EAR threshold below which an eye is considered closed
    threshold: f32,

    /// Number of consecutive frames required for wink detection
    wink_frames: i32,

    /// Counter for consecutive frames with eyes in wink state
    wink_counter: i32,

    /// Whether a wink has already been triggered (prevents repeat triggers)
    wink_triggered: bool,

    /// Counter for consecutive frames with eyes closed (for regular blink)
    blink_counter: i32,

    /// Last detected EAR values for debugging
    last_left_ear: f32,
    last_right_ear: f32,
}

impl BlinkDetector {
    /// Create a new blink detector
    ///
    /// # Arguments
    /// * `threshold` - EAR threshold for closed eye (typically 0.20-0.30)
    /// * `wink_frames` - Consecutive frames needed for wink detection
    pub fn new(threshold: f32, wink_frames: i32) -> Self {
        Self {
            threshold,
            wink_frames,
            wink_counter: 0,
            wink_triggered: false,
            blink_counter: 0,
            last_left_ear: 1.0,
            last_right_ear: 1.0,
        }
    }

    /// Update detector with new landmarks
    ///
    /// # Arguments
    /// * `landmarks` - Current frame's facial landmarks
    ///
    /// # Returns
    /// * `Some(BlinkEvent)` - If a blink or wink was detected
    /// * `None` - If no event (eyes open or transitioning)
    pub fn update(&mut self, landmarks: &FaceLandmarks) -> Option<BlinkEvent> {
        // Calculate EAR for both eyes
        let left_ear = landmarks.left_eye_aspect_ratio().unwrap_or(1.0);
        let right_ear = landmarks.right_eye_aspect_ratio().unwrap_or(1.0);

        self.last_left_ear = left_ear;
        self.last_right_ear = right_ear;

        // Determine if each eye is closed
        let left_closed = left_ear < self.threshold;
        let right_closed = right_ear < self.threshold;

        // Detect wink: exactly one eye closed
        let is_winking = (left_closed && !right_closed) || (right_closed && !left_closed);

        if is_winking {
            self.wink_counter += 1;
            self.blink_counter += 1;

            // Trigger wink event after sustained wink
            if self.wink_counter == self.wink_frames && !self.wink_triggered {
                self.wink_triggered = true;

                log::debug!(
                    "Wink detected! {} eye (L:{:.3} R:{:.3})",
                    if left_closed { "Left" } else { "Right" },
                    left_ear,
                    right_ear
                );

                return Some(BlinkEvent {
                    is_wink: true,
                    left_closed,
                    right_closed,
                    left_ear,
                    right_ear,
                });
            }
        } else {
            // Eyes opened or both closed (regular blink)

            // Check for regular blink (both eyes closed briefly then opened)
            let was_blinking = self.blink_counter >= 2 && !left_closed && !right_closed;

            // Reset counters
            self.wink_counter = 0;
            self.wink_triggered = false;
            self.blink_counter = 0;

            if was_blinking {
                // Regular blink detected (both eyes)
                return Some(BlinkEvent {
                    is_wink: false,
                    left_closed: false,
                    right_closed: false,
                    left_ear,
                    right_ear,
                });
            }
        }

        // Return some event if eyes are currently closed (for gaze pause)
        if left_closed || right_closed {
            Some(BlinkEvent {
                is_wink: false,
                left_closed,
                right_closed,
                left_ear,
                right_ear,
            })
        } else {
            None
        }
    }

    /// Check if currently in a blink/wink state
    pub fn is_blinking(&self) -> bool {
        self.blink_counter > 0
    }

    /// Get last detected EAR values
    pub fn get_last_ear(&self) -> (f32, f32) {
        (self.last_left_ear, self.last_right_ear)
    }

    /// Reset the detector state
    pub fn reset(&mut self) {
        self.wink_counter = 0;
        self.wink_triggered = false;
        self.blink_counter = 0;
    }

    /// Update threshold dynamically
    pub fn set_threshold(&mut self, threshold: f32) {
        self.threshold = threshold;
    }

    /// Update wink frames dynamically
    pub fn set_wink_frames(&mut self, frames: i32) {
        self.wink_frames = frames;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Point3D;

    fn create_landmarks_with_ears(left_ear: f32, right_ear: f32) -> FaceLandmarks {
        let mut landmarks = vec![Point3D::default(); 468];

        // Set left eye landmarks to achieve desired EAR
        // EAR = vertical / horizontal
        // Set horizontal distance to 0.1, calculate vertical from desired EAR
        let left_vertical = left_ear * 0.1;
        landmarks[FaceLandmarks::LEFT_EYE_TOP] = Point3D::new(0.4, 0.35, 0.0);
        landmarks[FaceLandmarks::LEFT_EYE_BOTTOM] = Point3D::new(0.4, 0.35 + left_vertical, 0.0);
        landmarks[FaceLandmarks::LEFT_EYE_LEFT] = Point3D::new(0.35, 0.36, 0.0);
        landmarks[FaceLandmarks::LEFT_EYE_RIGHT] = Point3D::new(0.45, 0.36, 0.0);

        // Set right eye landmarks
        let right_vertical = right_ear * 0.1;
        landmarks[FaceLandmarks::RIGHT_EYE_TOP] = Point3D::new(0.6, 0.35, 0.0);
        landmarks[FaceLandmarks::RIGHT_EYE_BOTTOM] = Point3D::new(0.6, 0.35 + right_vertical, 0.0);
        landmarks[FaceLandmarks::RIGHT_EYE_LEFT] = Point3D::new(0.55, 0.36, 0.0);
        landmarks[FaceLandmarks::RIGHT_EYE_RIGHT] = Point3D::new(0.65, 0.36, 0.0);

        FaceLandmarks { landmarks }
    }

    #[test]
    fn test_blink_detector_creation() {
        let detector = BlinkDetector::new(0.25, 8);
        assert!(!detector.is_blinking());
    }

    #[test]
    fn test_open_eyes_no_event() {
        let mut detector = BlinkDetector::new(0.25, 8);

        // Both eyes open (high EAR)
        let landmarks = create_landmarks_with_ears(0.35, 0.35);
        let result = detector.update(&landmarks);

        assert!(result.is_none());
        assert!(!detector.is_blinking());
    }

    #[test]
    fn test_wink_detection() {
        let mut detector = BlinkDetector::new(0.25, 3); // Short wink for testing

        // Left eye closed, right eye open
        let landmarks = create_landmarks_with_ears(0.15, 0.35);

        // First few frames - no trigger yet
        for _ in 0..2 {
            let result = detector.update(&landmarks);
            assert!(result.is_some());
            assert!(!result.unwrap().is_wink);
        }

        // Third frame - wink should trigger
        let result = detector.update(&landmarks);
        assert!(result.is_some());
        assert!(result.unwrap().is_wink);
        assert!(result.unwrap().left_closed);
        assert!(!result.unwrap().right_closed);
    }

    #[test]
    fn test_wink_no_repeat() {
        let mut detector = BlinkDetector::new(0.25, 2);

        // Left eye closed, right eye open
        let landmarks = create_landmarks_with_ears(0.15, 0.35);

        // Trigger wink
        detector.update(&landmarks);
        let result = detector.update(&landmarks);
        assert!(result.is_some() && result.unwrap().is_wink);

        // Continue holding - should not re-trigger
        for _ in 0..5 {
            let result = detector.update(&landmarks);
            assert!(result.is_some());
            assert!(!result.unwrap().is_wink, "Wink should not repeat");
        }
    }

    #[test]
    fn test_wink_reset_on_open() {
        let mut detector = BlinkDetector::new(0.25, 2);

        // Trigger wink
        let closed = create_landmarks_with_ears(0.15, 0.35);
        detector.update(&closed);
        detector.update(&closed);

        // Open eyes
        let open = create_landmarks_with_ears(0.35, 0.35);
        detector.update(&open);

        // Should be able to trigger again
        detector.update(&closed);
        let result = detector.update(&closed);
        assert!(result.is_some() && result.unwrap().is_wink);
    }

    #[test]
    fn test_both_eyes_closed_not_wink() {
        let mut detector = BlinkDetector::new(0.25, 2);

        // Both eyes closed (regular blink)
        let landmarks = create_landmarks_with_ears(0.15, 0.15);

        for _ in 0..5 {
            let result = detector.update(&landmarks);
            assert!(result.is_some());
            assert!(
                !result.unwrap().is_wink,
                "Both eyes closed should not be a wink"
            );
        }
    }

    #[test]
    fn test_get_last_ear() {
        let mut detector = BlinkDetector::new(0.25, 8);

        let landmarks = create_landmarks_with_ears(0.30, 0.35);
        detector.update(&landmarks);

        let (left, right) = detector.get_last_ear();
        assert!((left - 0.30).abs() < 0.01);
        assert!((right - 0.35).abs() < 0.01);
    }
}
