// C ABI bridge for MediaPipe FaceLandmarker (C++).
// Build with --features mediapipe and provide MEDIAPIPE_DIR + MEDIAPIPE_LINK_LIBS.
#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MPFaceLandmarker MPFaceLandmarker;

// Create a landmarker from a .task model path.
MPFaceLandmarker* mp_face_landmarker_create(const char* model_path);

// Destroy the landmarker.
void mp_face_landmarker_destroy(MPFaceLandmarker* landmarker);

// Process an RGB frame and write 468 landmarks (x,y,z) into out_landmarks.
// out_landmarks must be float array of size at least 468*3.
// Returns true if landmarks were produced.
bool mp_face_landmarker_process(
    MPFaceLandmarker* landmarker,
    const uint8_t* rgb_data,
    int width,
    int height,
    float* out_landmarks,
    int out_len);

#ifdef __cplusplus
} // extern "C"
#endif
