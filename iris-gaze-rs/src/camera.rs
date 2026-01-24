//! Camera capture module using OpenCV
//!
//! Provides efficient video frame capture from the system camera on macOS.

use opencv::{
    core::{AlgorithmHint, Mat},
    imgproc,
    prelude::*,
    videoio::{self, VideoCapture, CAP_ANY},
};

/// Error type for camera operations
#[derive(Debug)]
pub enum CameraError {
    /// No camera found
    NotFound,
    /// Failed to open camera
    OpenFailed(String),
    /// Failed to capture frame
    CaptureFailed(String),
    /// Camera not initialized
    NotInitialized,
    /// Invalid frame format
    InvalidFormat,
    /// OpenCV error
    OpenCVError(String),
}

impl From<opencv::Error> for CameraError {
    fn from(e: opencv::Error) -> Self {
        CameraError::OpenCVError(e.to_string())
    }
}

/// A video frame from the camera
#[derive(Clone)]
pub struct Frame {
    /// Raw pixel data in RGB format (row-major, 3 bytes per pixel)
    pub data: Vec<u8>,
    /// Frame width in pixels
    pub width: u32,
    /// Frame height in pixels
    pub height: u32,
}

impl Frame {
    /// Create a new empty frame with the given dimensions
    pub fn new(width: u32, height: u32) -> Self {
        let size = (width * height * 3) as usize; // RGB
        Self {
            data: vec![0u8; size],
            width,
            height,
        }
    }

    /// Create from OpenCV Mat (BGR format)
    pub fn from_mat(mat: &Mat) -> Result<Self, CameraError> {
        let rows = mat.rows() as u32;
        let cols = mat.cols() as u32;

        if rows == 0 || cols == 0 {
            return Err(CameraError::InvalidFormat);
        }

        // Convert BGR to RGB
        let mut rgb_mat = Mat::default();
        imgproc::cvt_color(
            mat,
            &mut rgb_mat,
            imgproc::COLOR_BGR2RGB,
            0,
            AlgorithmHint::ALGO_HINT_DEFAULT,
        )?;

        // Extract data
        let data = rgb_mat.data_bytes()?.to_vec();

        Ok(Self {
            data,
            width: cols,
            height: rows,
        })
    }

    /// Get pixel at (x, y) as (r, g, b)
    pub fn get_pixel(&self, x: u32, y: u32) -> Option<(u8, u8, u8)> {
        if x >= self.width || y >= self.height {
            return None;
        }
        let idx = ((y * self.width + x) * 3) as usize;
        if idx + 2 >= self.data.len() {
            return None;
        }
        Some((self.data[idx], self.data[idx + 1], self.data[idx + 2]))
    }

    /// Get data as a slice for ONNX input (normalized to 0-1 range)
    pub fn to_normalized_f32(&self) -> Vec<f32> {
        self.data.iter().map(|&b| b as f32 / 255.0).collect()
    }
}

/// Camera capture using OpenCV
pub struct Camera {
    capture: VideoCapture,
    width: u32,
    height: u32,
    frame_buffer: Mat,
    flipped_buffer: Mat,
    rgb_buffer: Mat,
}

impl Camera {
    /// Create a new camera with the given settings
    ///
    /// # Arguments
    /// * `width` - Desired frame width
    /// * `height` - Desired frame height
    /// * `fps` - Target frames per second
    pub fn new(width: i32, height: i32, fps: i32) -> Result<Self, CameraError> {
        log::info!(
            "Initializing OpenCV camera: {}x{} @ {}fps",
            width,
            height,
            fps
        );

        // Open the default camera (index 0)
        let mut capture = VideoCapture::new(0, CAP_ANY)?;

        if !capture.is_opened()? {
            return Err(CameraError::NotFound);
        }

        // Set camera properties
        capture.set(videoio::CAP_PROP_FRAME_WIDTH, width as f64)?;
        capture.set(videoio::CAP_PROP_FRAME_HEIGHT, height as f64)?;
        capture.set(videoio::CAP_PROP_FPS, fps as f64)?;

        // Read actual dimensions (camera may not support requested size)
        let actual_width = capture.get(videoio::CAP_PROP_FRAME_WIDTH)? as u32;
        let actual_height = capture.get(videoio::CAP_PROP_FRAME_HEIGHT)? as u32;

        log::info!(
            "Camera opened: actual size {}x{}",
            actual_width,
            actual_height
        );

        Ok(Self {
            capture,
            width: actual_width,
            height: actual_height,
            frame_buffer: Mat::default(),
            flipped_buffer: Mat::default(),
            rgb_buffer: Mat::default(),
        })
    }

    /// Capture a single frame from the camera
    pub fn capture_frame(&mut self) -> Result<Frame, CameraError> {
        // Read frame into buffer
        if !self.capture.read(&mut self.frame_buffer)? {
            return Err(CameraError::CaptureFailed("Failed to read frame".into()));
        }

        if self.frame_buffer.empty() {
            return Err(CameraError::CaptureFailed("Empty frame".into()));
        }

        // Flip horizontally (mirror) for natural interaction - reuse buffer
        opencv::core::flip(&self.frame_buffer, &mut self.flipped_buffer, 1)?;

        // Convert BGR to RGB - reuse buffer
        imgproc::cvt_color(
            &self.flipped_buffer,
            &mut self.rgb_buffer,
            imgproc::COLOR_BGR2RGB,
            0,
            AlgorithmHint::ALGO_HINT_DEFAULT,
        )?;

        // Extract data
        let rows = self.rgb_buffer.rows() as u32;
        let cols = self.rgb_buffer.cols() as u32;
        let data = self.rgb_buffer.data_bytes()?.to_vec();

        Ok(Frame {
            data,
            width: cols,
            height: rows,
        })
    }

    /// Check if camera is initialized and ready
    pub fn is_ready(&self) -> bool {
        self.capture.is_opened().unwrap_or(false)
    }

    /// Get the current frame dimensions
    pub fn dimensions(&self) -> (u32, u32) {
        (self.width, self.height)
    }
}

impl Drop for Camera {
    fn drop(&mut self) {
        log::info!("Releasing camera");
        let _ = self.capture.release();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_frame_creation() {
        let frame = Frame::new(640, 480);
        assert_eq!(frame.width, 640);
        assert_eq!(frame.height, 480);
        assert_eq!(frame.data.len(), 640 * 480 * 3);
    }

    #[test]
    fn test_frame_get_pixel() {
        let mut frame = Frame::new(10, 10);
        // Set pixel at (5, 5) to red
        let idx = (5 * 10 + 5) * 3;
        frame.data[idx] = 255; // R
        frame.data[idx + 1] = 0; // G
        frame.data[idx + 2] = 0; // B

        let pixel = frame.get_pixel(5, 5);
        assert_eq!(pixel, Some((255, 0, 0)));
    }

    #[test]
    fn test_frame_normalized() {
        let mut frame = Frame::new(2, 2);
        frame.data = vec![0, 128, 255, 0, 128, 255, 0, 128, 255, 0, 128, 255];

        let normalized = frame.to_normalized_f32();
        assert_eq!(normalized.len(), 12);
        assert!((normalized[0] - 0.0).abs() < 0.01);
        assert!((normalized[1] - 0.502).abs() < 0.01);
        assert!((normalized[2] - 1.0).abs() < 0.01);
    }
}
