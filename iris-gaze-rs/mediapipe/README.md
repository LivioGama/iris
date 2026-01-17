# MediaPipe (Option B)

This folder contains a C++ bridge so the Rust tracker can use MediaPipe's
FaceLandmarker (the same landmark source as the Python version).

## Build overview

1) Build or install MediaPipe C++ and Tasks libraries.
2) Export the install path via `MEDIAPIPE_DIR`.
3) Provide the libraries to link via `MEDIAPIPE_LINK_LIBS`.
4) Build the Rust crate with `--features mediapipe`.

## Environment variables

- `MEDIAPIPE_DIR`: path to an install layout containing `include/` and `lib/`
- `MEDIAPIPE_LINK_LIBS`: comma-separated library names (no `lib` prefix)

Example:

```
export MEDIAPIPE_DIR=/opt/mediapipe
export MEDIAPIPE_LINK_LIBS=mediapipe_tasks_vision,mediapipe_tasks_core,mediapipe_framework,absl_status,absl_strings
```

## Build command

```
cd iris-gaze-rs
cargo build --release --features mediapipe
```

If you use the root script:

```
USE_MEDIAPIPE=1 MEDIAPIPE_DIR=/opt/mediapipe MEDIAPIPE_LINK_LIBS=... ./build_and_install.sh
```

## Model file

The MediaPipe task file is expected at:
`iris-gaze-rs/models/face_landmarker.task`

The detector will fall back to ONNX if MediaPipe is unavailable.
