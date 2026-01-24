//! Face mesh detection using MediaPipe FaceMesh ONNX model
//!
//! Uses OpenCV Haar cascade for face detection and ONNX model for 468-point landmarks.

use crate::camera::Frame;
use crate::types::{FaceLandmarks, Point3D};
use opencv::{
    core::{AlgorithmHint, Mat, Rect, Size, Vector, CV_8UC3},
    imgproc,
    objdetect::CascadeClassifier,
    prelude::*,
};
use ort::{session::Session, value::Tensor};
use std::io::Write;
use std::path::Path;

/// Error type for face mesh operations
#[derive(Debug)]
pub enum FaceMeshError {
    ModelLoadFailed(String),
    InferenceFailed(String),
    InvalidInput(String),
    NotInitialized,
    OpenCVError(String),
    OrtError(String),
}

impl From<opencv::Error> for FaceMeshError {
    fn from(e: opencv::Error) -> Self {
        FaceMeshError::OpenCVError(e.to_string())
    }
}

impl From<ort::Error> for FaceMeshError {
    fn from(e: ort::Error) -> Self {
        FaceMeshError::OrtError(e.to_string())
    }
}

/// Face mesh detector using MediaPipe FaceMesh ONNX model for 468 landmarks
pub struct FaceMeshDetector {
    /// Haar cascade for face detection
    face_cascade: CascadeClassifier,
    /// ONNX session for face mesh
    onnx_session: Option<Session>,
    /// Whether ONNX model is available
    use_onnx: bool,
    /// Smoothed landmarks (468 points)
    smoothed_landmarks: Vec<Point3D>,
    /// Smoothing factor (EMA alpha)
    alpha: f32,
    /// Frame counter
    frame_count: u32,
    /// Last detected face
    last_face: Option<Rect>,
    /// Whether initialized
    initialized: bool,
    /// Image dimensions
    img_width: f32,
    img_height: f32,
    /// Log file for debugging
    log_file: Option<std::fs::File>,
}

impl FaceMeshDetector {
    pub fn new() -> Result<Self, FaceMeshError> {
        // Open log file
        let mut log_file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open("/tmp/iris_rust.log")
            .ok();

        let log = |file: &mut Option<std::fs::File>, msg: &str| {
            if let Some(ref mut f) = file {
                let _ = writeln!(f, "{}", msg);
            }
        };

        log(&mut log_file, "FaceMeshDetector::new() starting...");

        // Load Haar cascade for face detection
        let haar_paths = [
            "/opt/homebrew/share/opencv4/haarcascades/haarcascade_frontalface_default.xml",
            "/usr/local/share/opencv4/haarcascades/haarcascade_frontalface_default.xml",
            "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml",
        ];

        let mut face_cascade = None;
        for path in &haar_paths {
            if Path::new(path).exists() {
                match CascadeClassifier::new(path) {
                    Ok(cascade) => {
                        log(
                            &mut log_file,
                            &format!("✅ Loaded Haar cascade from {}", path),
                        );
                        face_cascade = Some(cascade);
                        break;
                    }
                    Err(e) => log(
                        &mut log_file,
                        &format!("❌ Failed to load Haar cascade {}: {}", path, e),
                    ),
                }
            }
        }

        let face_cascade = face_cascade
            .ok_or_else(|| FaceMeshError::ModelLoadFailed("No Haar cascade found".into()))?;

        // Try to load MediaPipe FaceMesh ONNX model (simplified single-input version)
        let onnx_paths = [
            "/Users/livio/Documents/iris/iris-gaze-rs/models/face_mesh_simple.onnx",
            "models/face_mesh_simple.onnx",
            "iris-gaze-rs/models/face_mesh_simple.onnx",
        ];

        let mut onnx_session = None;
        let mut use_onnx = false;

        for model_path in &onnx_paths {
            log(
                &mut log_file,
                &format!("Checking ONNX path: {}", model_path),
            );
            if Path::new(model_path).exists() {
                log(
                    &mut log_file,
                    &format!("🔍 Found ONNX model at {}", model_path),
                );
                match Session::builder() {
                    Ok(builder) => match builder.commit_from_file(model_path) {
                        Ok(session) => {
                            log(&mut log_file, "✅ MediaPipe FaceMesh ONNX model loaded!");
                            onnx_session = Some(session);
                            use_onnx = true;
                            break;
                        }
                        Err(e) => {
                            log(
                                &mut log_file,
                                &format!("❌ Failed to load ONNX model: {}", e),
                            );
                        }
                    },
                    Err(e) => {
                        log(
                            &mut log_file,
                            &format!("❌ Failed to create ONNX builder: {}", e),
                        );
                    }
                }
            }
        }

        if !use_onnx {
            log(
                &mut log_file,
                "⚠️ ONNX not available, falling back to face box estimation",
            );
        } else {
            log(
                &mut log_file,
                "🎯 Using MediaPipe FaceMesh ONNX for 468-point landmarks",
            );
        }

        Ok(Self {
            face_cascade,
            onnx_session,
            use_onnx,
            smoothed_landmarks: vec![Point3D::default(); 468],
            alpha: 0.35, // EMA smoothing factor
            frame_count: 0,
            last_face: None,
            initialized: false,
            img_width: 640.0,
            img_height: 480.0,
            log_file,
        })
    }

    fn log(&mut self, msg: &str) {
        if let Some(ref mut f) = self.log_file {
            let _ = writeln!(f, "{}", msg);
        }
    }

    /// Detect faces in the frame
    fn detect_faces(&mut self, gray: &Mat) -> Result<Vector<Rect>, FaceMeshError> {
        let mut faces: Vector<Rect> = Vector::new();

        self.face_cascade.detect_multi_scale(
            gray,
            &mut faces,
            1.1,               // scale factor
            3,                 // min neighbors
            0,                 // flags
            Size::new(60, 60), // min size
            Size::new(0, 0),   // max size
        )?;

        if !faces.is_empty() {
            self.last_face = Some(faces.get(0)?);
        }

        Ok(faces)
    }

    /// Detect 468-point landmarks using ONNX model
    fn detect_landmarks_onnx(
        &mut self,
        frame: &Frame,
        face: &Rect,
    ) -> Result<Option<Vec<Point3D>>, FaceMeshError> {
        // Debug logging - log more frequently to track issues
        static mut ONNX_CALL_COUNT: u32 = 0;
        let call_count = unsafe {
            ONNX_CALL_COUNT += 1;
            ONNX_CALL_COUNT
        };

        let session = match &mut self.onnx_session {
            Some(s) => s,
            None => return Ok(None),
        };

        // Add margin to face box (25% on each side as per MediaPipe spec)
        let margin = 0.25;
        let margin_x = (face.width as f32 * margin) as i32;
        let margin_y = (face.height as f32 * margin) as i32;

        let crop_x1 = (face.x - margin_x).max(0);
        let crop_y1 = (face.y - margin_y).max(0);
        let crop_x2 = (face.x + face.width + margin_x).min(frame.width as i32);
        let crop_y2 = (face.y + face.height + margin_y).min(frame.height as i32);
        let crop_width = crop_x2 - crop_x1;
        let crop_height = crop_y2 - crop_y1;

        if crop_width <= 0 || crop_height <= 0 {
            return Ok(None);
        }

        let frame_w = frame.width as usize;
        let frame_h = frame.height as usize;

        // Create input tensor: [1, 3, 192, 192]
        // Crop and resize face region to 192x192
        let mut input_data: Vec<f32> = vec![0.0; 1 * 3 * 192 * 192];

        // Extract and resize the face crop
        for y in 0..192usize {
            for x in 0..192usize {
                // Map to source coordinates
                let src_x = crop_x1 as usize + (x * crop_width as usize) / 192;
                let src_y = crop_y1 as usize + (y * crop_height as usize) / 192;

                if src_x < frame_w && src_y < frame_h {
                    let src_idx = (src_y * frame_w + src_x) * 3;
                    if src_idx + 2 < frame.data.len() {
                        // RGB -> normalize to [0, 1], layout: [N, C, H, W]
                        let dst_idx_r = 0 * 192 * 192 + y * 192 + x;
                        let dst_idx_g = 1 * 192 * 192 + y * 192 + x;
                        let dst_idx_b = 2 * 192 * 192 + y * 192 + x;
                        input_data[dst_idx_r] = frame.data[src_idx] as f32 / 255.0;
                        input_data[dst_idx_g] = frame.data[src_idx + 1] as f32 / 255.0;
                        input_data[dst_idx_b] = frame.data[src_idx + 2] as f32 / 255.0;
                    }
                }
            }
        }

        // Create tensors using the proper API
        // Note: input is float32, but crop coordinates are int32 as per model spec
        let input_tensor =
            Tensor::from_array(([1usize, 3, 192, 192], input_data.into_boxed_slice()))?;

        // Run inference with simplified model (only image input, crop params are constants)
        let outputs = match session.run(ort::inputs![
            "input" => input_tensor,
        ]) {
            Ok(o) => {
                if call_count <= 3 {
                    let _ = std::fs::OpenOptions::new()
                        .create(true)
                        .append(true)
                        .open("/tmp/iris_onnx_debug.log")
                        .and_then(|mut f| writeln!(f, "ONNX inference SUCCESS"));
                }
                o
            }
            Err(e) => {
                let _ = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open("/tmp/iris_onnx_debug.log")
                    .and_then(|mut f| writeln!(f, "ONNX inference FAILED: {:?}", e));
                return Err(e.into());
            }
        };

        // Extract landmarks from output
        // Output shape: [1, 468, 3] (x, y, z for each landmark)
        // Note: output is int32, not float32!
        let landmarks_output = outputs
            .get("final_landmarks")
            .ok_or_else(|| FaceMeshError::InferenceFailed("No landmarks output".into()))?;

        let (shape, landmarks_data) = landmarks_output.try_extract_tensor::<i32>()?;

        // Shape is [1, 468, 3]
        if shape.len() < 3 {
            return Err(FaceMeshError::InferenceFailed(format!(
                "Unexpected output shape: {:?}",
                shape
            )));
        }

        let mut landmarks = Vec::with_capacity(468);

        // Log first few frames to debug coordinate system
        static mut FRAME_LOG_COUNT: u32 = 0;
        let log_count = unsafe {
            FRAME_LOG_COUNT += 1;
            FRAME_LOG_COUNT
        };

        // Write to separate debug file for first 5 frames
        if log_count <= 5 && landmarks_data.len() >= 33 {
            let nx = landmarks_data[4 * 3] as f32;
            let ny = landmarks_data[4 * 3 + 1] as f32;
            let fx = landmarks_data[10 * 3] as f32;
            let fy = landmarks_data[10 * 3 + 1] as f32;

            let norm_nx = (crop_x1 as f32 + (nx * crop_width as f32 / 192.0)) / frame.width as f32;
            let norm_ny =
                (crop_y1 as f32 + (ny * crop_height as f32 / 192.0)) / frame.height as f32;
            let norm_fx = (crop_x1 as f32 + (fx * crop_width as f32 / 192.0)) / frame.width as f32;
            let norm_fy =
                (crop_y1 as f32 + (fy * crop_height as f32 / 192.0)) / frame.height as f32;

            let _ = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_onnx_debug.log")
                .and_then(|mut f| {
                    writeln!(
                        f,
                        "Frame {}: nose=({:.4}, {:.4}) forehead=({:.4}, {:.4}) raw_n=({}, {}) img={}x{}",
                        log_count,
                        norm_nx,
                        norm_ny,
                        norm_fx,
                        norm_fy,
                        nx,
                        ny,
                        frame.width,
                        frame.height
                    )
                });
        }

        // Build landmarks - ONNX outputs [1, 468, 3] as flat array of 1404 i32s
        let data_len = landmarks_data.len();
        for i in 0..468 {
            let base = i * 3;
            if base + 2 < data_len {
                let x = landmarks_data[base] as f32;
                let y = landmarks_data[base + 1] as f32;
                let z = landmarks_data[base + 2] as f32;

                // Map from 192x192 crop space to global image space
                let global_x = crop_x1 as f32 + (x * crop_width as f32 / 192.0);
                let global_y = crop_y1 as f32 + (y * crop_height as f32 / 192.0);

                // Normalize to 0-1 relative to full frame (matching MediaPipe behavior)
                let norm_x = global_x / frame.width as f32;
                let norm_y = global_y / frame.height as f32;

                landmarks.push(Point3D::new(norm_x, norm_y, z));
            } else {
                landmarks.push(Point3D::default());
            }
        }

        Ok(Some(landmarks))
    }

    /// Estimate landmarks from face bounding box (fallback)
    fn estimate_landmarks_from_box(&self, face: &Rect) -> Vec<Point3D> {
        let mut landmarks = vec![Point3D::default(); 468];

        let cx = (face.x as f32 + face.width as f32 / 2.0) / self.img_width;
        let cy = (face.y as f32 + face.height as f32 / 2.0) / self.img_height;
        let w = face.width as f32 / self.img_width;
        let h = face.height as f32 / self.img_height;

        // MediaPipe landmark indices:
        // 4: Nose tip
        // 10: Forehead
        // 159, 145: Left eye top/bottom
        // 386, 374: Right eye top/bottom

        // Nose tip (index 4)
        landmarks[4] = Point3D::new(cx, cy + h * 0.15, 0.0);

        // Forehead (index 10)
        landmarks[10] = Point3D::new(cx, cy - h * 0.25, 0.0);

        // Left eye
        let left_eye_x = cx - w * 0.15;
        let left_eye_y = cy - h * 0.08;
        landmarks[159] = Point3D::new(left_eye_x, left_eye_y - h * 0.03, 0.0); // top
        landmarks[145] = Point3D::new(left_eye_x, left_eye_y + h * 0.03, 0.0); // bottom
        landmarks[33] = Point3D::new(left_eye_x - w * 0.05, left_eye_y, 0.0); // left
        landmarks[133] = Point3D::new(left_eye_x + w * 0.05, left_eye_y, 0.0); // right

        // Right eye
        let right_eye_x = cx + w * 0.15;
        let right_eye_y = cy - h * 0.08;
        landmarks[386] = Point3D::new(right_eye_x, right_eye_y - h * 0.03, 0.0); // top
        landmarks[374] = Point3D::new(right_eye_x, right_eye_y + h * 0.03, 0.0); // bottom
        landmarks[362] = Point3D::new(right_eye_x - w * 0.05, right_eye_y, 0.0); // left
        landmarks[263] = Point3D::new(right_eye_x + w * 0.05, right_eye_y, 0.0); // right

        landmarks
    }

    /// Apply EMA smoothing to landmarks
    fn smooth_landmarks(&mut self, new_landmarks: &[Point3D]) {
        if !self.initialized || self.smoothed_landmarks.len() != new_landmarks.len() {
            self.smoothed_landmarks = new_landmarks.to_vec();
            self.initialized = true;
            return;
        }

        for (i, new_pt) in new_landmarks.iter().enumerate() {
            if i < self.smoothed_landmarks.len() {
                // EMA smoothing
                self.smoothed_landmarks[i].x +=
                    self.alpha * (new_pt.x - self.smoothed_landmarks[i].x);
                self.smoothed_landmarks[i].y +=
                    self.alpha * (new_pt.y - self.smoothed_landmarks[i].y);
                self.smoothed_landmarks[i].z +=
                    self.alpha * (new_pt.z - self.smoothed_landmarks[i].z);
            }
        }
    }

    /// Convert landmarks to FaceLandmarks format
    fn to_face_landmarks(&self, landmarks: &[Point3D]) -> FaceLandmarks {
        FaceLandmarks {
            landmarks: landmarks.to_vec(),
        }
    }

    pub fn detect(&mut self, frame: &Frame) -> Result<Option<FaceLandmarks>, FaceMeshError> {
        self.frame_count += 1;
        self.img_width = frame.width as f32;
        self.img_height = frame.height as f32;

        // Debug: log every 60 frames
        if self.frame_count <= 3 || self.frame_count % 60 == 0 {
            let _ = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_onnx_debug.log")
                .and_then(|mut f| {
                    writeln!(
                        f,
                        "detect() frame #{}, {}x{}, use_onnx={}",
                        self.frame_count, frame.width, frame.height, self.use_onnx
                    )
                });
        }

        // Convert frame to OpenCV Mat for face detection
        let img = unsafe {
            Mat::new_rows_cols_with_data_unsafe(
                frame.height as i32,
                frame.width as i32,
                CV_8UC3,
                frame.data.as_ptr() as *mut std::ffi::c_void,
                opencv::core::Mat_AUTO_STEP,
            )?
        };

        // Convert to grayscale
        let mut gray = Mat::default();
        imgproc::cvt_color(
            &img,
            &mut gray,
            imgproc::COLOR_RGB2GRAY,
            0,
            AlgorithmHint::ALGO_HINT_DEFAULT,
        )?;

        // Detect faces every 3rd frame for performance
        let faces = if self.frame_count % 3 == 0 || self.last_face.is_none() {
            self.detect_faces(&gray)?
        } else if let Some(face) = self.last_face {
            let mut v = Vector::new();
            v.push(face);
            v
        } else {
            Vector::new()
        };

        if faces.is_empty() {
            // Return last known landmarks if face temporarily lost
            if self.initialized {
                return Ok(Some(self.to_face_landmarks(&self.smoothed_landmarks)));
            }
            return Ok(None);
        }

        let face = faces.get(0)?;

        // Try ONNX model first (468 landmarks with iris tracking)
        let raw_landmarks = if self.use_onnx {
            match self.detect_landmarks_onnx(frame, &face) {
                Ok(Some(lm)) => lm,
                Ok(None) => {
                    self.log("ONNX returned None");
                    self.estimate_landmarks_from_box(&face)
                }
                Err(e) => {
                    // Log error only first few times
                    static mut ERR_COUNT: u32 = 0;
                    unsafe {
                        ERR_COUNT += 1;
                        if ERR_COUNT <= 3 {
                            if let Some(ref mut f) = self.log_file {
                                let _ = writeln!(f, "ONNX error: {:?}", e);
                            }
                        }
                    }
                    self.estimate_landmarks_from_box(&face)
                }
            }
        } else {
            self.estimate_landmarks_from_box(&face)
        };

        // Apply smoothing
        self.smooth_landmarks(&raw_landmarks);

        // Log successful detection
        static mut DETECT_SUCCESS_COUNT: u32 = 0;
        let dcount = unsafe {
            DETECT_SUCCESS_COUNT += 1;
            DETECT_SUCCESS_COUNT
        };
        if dcount <= 5 {
            let _ = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open("/tmp/iris_onnx_debug.log")
                .and_then(|mut f| {
                    writeln!(
                        f,
                        "DETECT SUCCESS #{}: returning {} landmarks",
                        dcount,
                        self.smoothed_landmarks.len()
                    )
                });
        }

        Ok(Some(self.to_face_landmarks(&self.smoothed_landmarks)))
    }

    pub fn is_ready(&self) -> bool {
        true
    }
}

impl Drop for FaceMeshDetector {
    fn drop(&mut self) {
        self.log("Face mesh detector released");
    }
}
