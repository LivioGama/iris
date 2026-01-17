//! MediaPipe FaceLandmarker bridge (C++ FFI).
//! Requires building with --features mediapipe and setting MEDIAPIPE_DIR.

use crate::types::Point3D;
use std::ffi::CString;
use std::os::raw::c_char;

#[repr(C)]
struct MPFaceLandmarker;

extern "C" {
    fn mp_face_landmarker_create(model_path: *const c_char) -> *mut MPFaceLandmarker;
    fn mp_face_landmarker_destroy(landmarker: *mut MPFaceLandmarker);
    fn mp_face_landmarker_process(
        landmarker: *mut MPFaceLandmarker,
        rgb_data: *const u8,
        width: i32,
        height: i32,
        out_landmarks: *mut f32,
        out_len: i32,
    ) -> bool;
}

pub struct MediaPipeDetector {
    handle: *mut MPFaceLandmarker,
}

impl MediaPipeDetector {
    pub fn new(model_path: &str) -> Result<Self, String> {
        let c_path = CString::new(model_path).map_err(|e| e.to_string())?;
        let handle = unsafe { mp_face_landmarker_create(c_path.as_ptr()) };
        if handle.is_null() {
            return Err("Failed to create MediaPipe FaceLandmarker".into());
        }
        Ok(Self { handle })
    }

    pub fn detect(&mut self, rgb: &[u8], width: i32, height: i32) -> Option<Vec<Point3D>> {
        if self.handle.is_null() {
            return None;
        }
        let mut landmarks = vec![0f32; 468 * 3];
        let ok = unsafe {
            mp_face_landmarker_process(
                self.handle,
                rgb.as_ptr(),
                width,
                height,
                landmarks.as_mut_ptr(),
                landmarks.len() as i32,
            )
        };
        if !ok {
            return None;
        }
        let mut points = Vec::with_capacity(468);
        for i in 0..468 {
            let idx = i * 3;
            points.push(Point3D::new(
                landmarks[idx],
                landmarks[idx + 1],
                landmarks[idx + 2],
            ));
        }
        Some(points)
    }
}

impl Drop for MediaPipeDetector {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            unsafe { mp_face_landmarker_destroy(self.handle) };
            self.handle = std::ptr::null_mut();
        }
    }
}
