#include "mediapipe_bridge.h"

#ifdef MEDIAPIPE_AVAILABLE
#include <memory>
#include <string>

#include "mediapipe/framework/formats/image_frame.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/tasks/cc/core/base_options.h"
#include "mediapipe/tasks/cc/vision/core/vision_task_running_mode.h"
#include "mediapipe/tasks/cc/vision/face_landmarker/face_landmarker.h"
#include "mediapipe/tasks/cc/vision/face_landmarker/face_landmarker_options.h"
#include "mediapipe/tasks/cc/vision/face_landmarker/face_landmarker_result.h"

using mediapipe::ImageFrame;
using mediapipe::ImageFormat;
using mediapipe::tasks::core::BaseOptions;
using mediapipe::tasks::vision::core::VisionTaskRunningMode;
using mediapipe::tasks::vision::face_landmarker::FaceLandmarker;
using mediapipe::tasks::vision::face_landmarker::FaceLandmarkerOptions;

struct MPFaceLandmarker {
  std::unique_ptr<FaceLandmarker> landmarker;
};

MPFaceLandmarker* mp_face_landmarker_create(const char* model_path) {
  if (!model_path) {
    return nullptr;
  }

  FaceLandmarkerOptions options;
  BaseOptions base_options;
  base_options.model_asset_path = std::string(model_path);
  options.base_options = base_options;
  options.running_mode = VisionTaskRunningMode::IMAGE;
  options.output_face_blendshapes = false;
  options.output_facial_transformation_matrixes = false;
  options.num_faces = 1;

  auto landmarker_or = FaceLandmarker::CreateFromOptions(options);
  if (!landmarker_or.ok()) {
    return nullptr;
  }

  MPFaceLandmarker* wrapper = new MPFaceLandmarker();
  wrapper->landmarker = std::move(landmarker_or.value());
  return wrapper;
}

void mp_face_landmarker_destroy(MPFaceLandmarker* landmarker) {
  if (!landmarker) {
    return;
  }
  delete landmarker;
}

bool mp_face_landmarker_process(
    MPFaceLandmarker* landmarker,
    const uint8_t* rgb_data,
    int width,
    int height,
    float* out_landmarks,
    int out_len) {
  if (!landmarker || !landmarker->landmarker || !rgb_data || !out_landmarks) {
    return false;
  }
  if (out_len < 468 * 3) {
    return false;
  }

  auto frame = std::make_shared<ImageFrame>(ImageFormat::SRGB, width, height,
                                            width * 3);
  std::memcpy(frame->MutablePixelData(), rgb_data, width * height * 3);

  auto image = mediapipe::Image(frame);
  auto result_or = landmarker->landmarker->Detect(image);
  if (!result_or.ok()) {
    return false;
  }

  const auto& result = result_or.value();
  if (result.face_landmarks.empty()) {
    return false;
  }

  const auto& landmarks = result.face_landmarks[0];
  if (landmarks.landmark_size() < 468) {
    return false;
  }

  for (int i = 0; i < 468; i++) {
    const auto& lm = landmarks.landmark(i);
    out_landmarks[i * 3 + 0] = lm.x();
    out_landmarks[i * 3 + 1] = lm.y();
    out_landmarks[i * 3 + 2] = lm.z();
  }

  return true;
}

#else

struct MPFaceLandmarker {};

MPFaceLandmarker* mp_face_landmarker_create(const char* /*model_path*/) {
  return nullptr;
}

void mp_face_landmarker_destroy(MPFaceLandmarker* /*landmarker*/) {}

bool mp_face_landmarker_process(
    MPFaceLandmarker* /*landmarker*/,
    const uint8_t* /*rgb_data*/,
    int /*width*/,
    int /*height*/,
    float* /*out_landmarks*/,
    int /*out_len*/) {
  return false;
}

#endif
