//! Python MediaPipe face mesh integration
//!
//! Uses a Python subprocess running MediaPipe for face landmark detection.
//! This gives us the exact same coordinates as the Python implementation.

use crate::types::{FaceLandmarks, Point3D};
use std::io::{BufRead, BufReader, Write};
use std::process::{Child, Command, Stdio};

fn log(msg: &str) {
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open("/tmp/iris_rust.log")
    {
        let _ = writeln!(f, "{}", msg);
    }
}

#[derive(Debug)]
pub enum PythonFaceMeshError {
    ProcessSpawnFailed(String),
    ReadError(String),
    ParseError(String),
}

pub struct PythonFaceMeshDetector {
    child: Child,
    reader: BufReader<std::process::ChildStdout>,
    ready: bool,
}

impl PythonFaceMeshDetector {
    pub fn new(camera_index: i32) -> Result<Self, PythonFaceMeshError> {
        log(&format!("🐍 Starting Python MediaPipe face mesh server with camera index {}...", camera_index));

        // Find Python script
        let script_paths = [
            "/Users/livio/Documents/iris/iris-gaze-rs/scripts/face_mesh_server.py",
            "scripts/face_mesh_server.py",
        ];

        let script_path = script_paths
            .iter()
            .find(|p| std::path::Path::new(p).exists())
            .ok_or_else(|| {
                PythonFaceMeshError::ProcessSpawnFailed("face_mesh_server.py not found".into())
            })?;

        // Find Python with MediaPipe
        let python_paths = [
            "/Users/livio/Documents/iris/gaze_env/bin/python3",
            "/opt/homebrew/bin/python3",
            "python3",
        ];

        let python = python_paths
            .iter()
            .find(|p| {
                std::process::Command::new(p)
                    .arg("--version")
                    .output()
                    .is_ok()
            })
            .ok_or_else(|| PythonFaceMeshError::ProcessSpawnFailed("Python not found".into()))?;

        log(&format!("🐍 Using Python: {}", python));
        log(&format!("🐍 Script: {}", script_path));

        let mut child = Command::new(python)
            .arg(script_path)
            .arg("--index")
            .arg(camera_index.to_string())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| PythonFaceMeshError::ProcessSpawnFailed(e.to_string()))?;

        let stdout = child.stdout.take().ok_or_else(|| {
            PythonFaceMeshError::ProcessSpawnFailed("Failed to get stdout".into())
        })?;

        let mut reader = BufReader::new(stdout);

        // Wait for ready message
        let mut line = String::new();
        reader
            .read_line(&mut line)
            .map_err(|e| PythonFaceMeshError::ReadError(e.to_string()))?;

        if line.contains("ready") {
            log("✅ Python MediaPipe face mesh server ready");
        } else {
            log(&format!("⚠️ Unexpected first line: {}", line.trim()));
        }

        Ok(Self {
            child,
            reader,
            ready: true,
        })
    }

    /// Read next frame of landmarks from Python
    pub fn detect(&mut self) -> Result<Option<FaceLandmarks>, PythonFaceMeshError> {
        if !self.ready {
            return Err(PythonFaceMeshError::ProcessSpawnFailed(
                "Not initialized".into(),
            ));
        }

        let mut line = String::new();
        match self.reader.read_line(&mut line) {
            Ok(0) => {
                // EOF - process died
                self.ready = false;
                return Err(PythonFaceMeshError::ReadError("Process ended".into()));
            }
            Ok(_) => {}
            Err(e) => return Err(PythonFaceMeshError::ReadError(e.to_string())),
        }

        // Parse JSON
        let json: serde_json::Value = serde_json::from_str(&line)
            .map_err(|e| PythonFaceMeshError::ParseError(e.to_string()))?;

        if json.get("landmarks").and_then(|v| v.as_null()).is_some() {
            // No face detected
            return Ok(None);
        }

        let landmarks_obj = match json.get("landmarks") {
            Some(v) => v,
            None => return Ok(None),
        };

        // Build FaceLandmarks from the key points
        let mut landmarks = vec![Point3D::default(); 468];

        // Helper to extract a point
        let get_point = |obj: &serde_json::Value, key: &str| -> Point3D {
            if let Some(p) = obj.get(key) {
                Point3D {
                    x: p.get("x").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
                    y: p.get("y").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
                    z: p.get("z").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
                }
            } else {
                Point3D::default()
            }
        };

        // Fill in the key landmarks
        landmarks[4] = get_point(landmarks_obj, "4"); // Nose tip
        landmarks[10] = get_point(landmarks_obj, "10"); // Forehead

        // Left eye
        landmarks[33] = get_point(landmarks_obj, "33");
        landmarks[133] = get_point(landmarks_obj, "133");
        landmarks[159] = get_point(landmarks_obj, "159");
        landmarks[145] = get_point(landmarks_obj, "145");

        // Right eye
        landmarks[362] = get_point(landmarks_obj, "362");
        landmarks[263] = get_point(landmarks_obj, "263");
        landmarks[386] = get_point(landmarks_obj, "386");
        landmarks[374] = get_point(landmarks_obj, "374");

        Ok(Some(FaceLandmarks::new(landmarks)))
    }
}

impl Drop for PythonFaceMeshDetector {
    fn drop(&mut self) {
        log("🐍 Stopping Python MediaPipe face mesh server");
        let _ = self.child.kill();
    }
}
