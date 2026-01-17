#!/usr/bin/env python3
import sys
import json
import cv2
import os
import numpy as np
import mediapipe as mp

os.environ["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"

mp_face_mesh = mp.solutions.face_mesh

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--eye', choices=['left', 'right'], default='left')
    parser.add_argument('screen_width', type=int, nargs='?', default=1440)
    parser.add_argument('screen_height', type=int, nargs='?', default=900)
    args = parser.parse_args()

    screen_width = args.screen_width
    screen_height = args.screen_height

    print(json.dumps({"status": "started"}), flush=True)

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    ema_x, ema_y = screen_width / 2, screen_height / 2
    ema_nose_x, ema_nose_y = 0.5, 0.5

    # Blink detection thresholds
    EYE_AR_THRESH = 0.21
    EYE_AR_CONSEC_FRAMES = 2
    blink_counter = 0
    is_blinking = False

    # Long blink detection for screenshot trigger
    # Normal blink: ~3-9 frames (0.1-0.3 seconds)
    # Intentional long blink: 15-18 frames (0.5-0.6 seconds) - noticeable but not too long
    LONG_BLINK_THRESH = 15
    eyes_closed_counter = 0
    long_blink_triggered = False

    # Fixed tracking ranges (based on measured values)
    nose_x_min, nose_x_max = 0.5174, 0.5967
    nose_y_min, nose_y_max = 0.3542, 0.3910

    print(json.dumps({"status": "calibrated"}), flush=True)

    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:

        while True:
            ret, frame = cap.read()
            if not ret:
                continue

            frame = cv2.flip(frame, 1)

            try:
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = face_mesh.process(rgb)

                if not results.multi_face_landmarks:
                    continue

                landmarks = results.multi_face_landmarks[0].landmark

                # Blink detection using eye aspect ratio
                left_eye_top = landmarks[159]
                left_eye_bottom = landmarks[145]
                left_eye_left = landmarks[33]
                left_eye_right = landmarks[133]

                vertical_dist = abs(left_eye_top.y - left_eye_bottom.y)
                horizontal_dist = abs(left_eye_right.x - left_eye_left.x)
                eye_aspect_ratio = vertical_dist / horizontal_dist if horizontal_dist > 0 else 1.0

                if eye_aspect_ratio < EYE_AR_THRESH:
                    blink_counter += 1
                    eyes_closed_counter += 1

                    # Show progress feedback at key milestones
                    # At 5 frames (~0.17s): indicate detection started
                    # At 10 frames (~0.33s): halfway to trigger
                    # At 15 frames (~0.5s): trigger!
                    if eyes_closed_counter == 5:
                        print(json.dumps({
                            "status": "blink_detected_keep_closed"
                        }), flush=True)
                    elif eyes_closed_counter == 10:
                        print(json.dumps({
                            "status": "halfway_to_trigger"
                        }), flush=True)

                    # Check for intentional long blink trigger
                    if eyes_closed_counter >= LONG_BLINK_THRESH and not long_blink_triggered:
                        long_blink_triggered = True
                        print(json.dumps({
                            "status": "long_blink_triggered"
                        }), flush=True)
                        # Send blink event for screenshot
                        print(json.dumps({
                            "event": "blink",
                            "x": ema_x,
                            "y": ema_y
                        }), flush=True)
                else:
                    if blink_counter >= EYE_AR_CONSEC_FRAMES:
                        is_blinking = True
                    blink_counter = 0
                    eyes_closed_counter = 0
                    long_blink_triggered = False

                if is_blinking and blink_counter == 0:
                    is_blinking = False

                # Use nose for horizontal, forehead for vertical
                nose = landmarks[4]
                forehead = landmarks[10]
                nose_x = nose.x
                nose_y = forehead.y

                # Don't update position during blink or when eyes are closed
                if is_blinking or eyes_closed_counter > 0:
                    continue

                # Very heavy smoothing for stable hovering
                ema_nose_x += (nose_x - ema_nose_x) * 0.10
                ema_nose_y += (nose_y - ema_nose_y) * 0.10

                h_norm = (ema_nose_x - nose_x_min) / (nose_x_max - nose_x_min)
                v_norm = (ema_nose_y - nose_y_min) / (nose_y_max - nose_y_min)

                # Apply center deadzone to prevent drift
                deadzone = 0.08
                if abs(h_norm - 0.5) < deadzone:
                    h_norm = 0.5
                if abs(v_norm - 0.5) < deadzone:
                    v_norm = 0.5

                h_norm = max(0, min(1, h_norm))
                v_norm = max(0, min(1, v_norm))

                target_x = h_norm * screen_width
                target_y = v_norm * screen_height

                dx = target_x - ema_x
                dy = target_y - ema_y
                dist = (dx*dx + dy*dy) ** 0.5

                # Much slower cursor movement for stability
                if dist > 8:
                    ema_x += dx * 0.15
                    ema_y += dy * 0.15
                else:
                    ema_x = target_x
                    ema_y = target_y

                print(json.dumps({
                    "x": ema_x,
                    "y": ema_y,
                    "h": ema_x / screen_width,
                    "v": ema_y / screen_height,
                    "nose_x": ema_nose_x,
                    "nose_y": ema_nose_y
                }), flush=True)

            except Exception as e:
                continue

if __name__ == "__main__":
    main()
