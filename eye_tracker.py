#!/usr/bin/env python3
import sys
import json
import struct
import cv2
import os
import numpy as np
import mediapipe as mp

os.environ["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"

# Binary protocol types
TYPE_GAZE = 1
TYPE_BLINK = 2
TYPE_STATUS = 3
TYPE_CALIBRATE = 4

mp_face_mesh = mp.solutions.face_mesh

def send_binary_gaze(x, y):
    """Send gaze coordinates using binary protocol (17 bytes)"""
    # Format: [uint8 type][float64 x][float64 y]
    data = struct.pack('!Bdd', TYPE_GAZE, x, y)
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()

def send_binary_blink(x, y):
    """Send blink event using binary protocol"""
    data = struct.pack('!Bdd', TYPE_BLINK, x, y)
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()

def send_json_status(status):
    """Send status messages (still use JSON for compatibility)"""
    print(json.dumps({"status": status}), flush=True)

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

    # Blink detection thresholds - balanced to work but prevent false triggers
    EYE_AR_THRESH = 0.25  # Threshold for closed eye
    EYE_AR_CONSEC_FRAMES = 2
    blink_counter = 0
    is_blinking = False

    # Long blink detection for screenshot trigger
    # Require sustained wink of 8 frames (0.27 seconds)
    LONG_BLINK_THRESH = 8

    # Debug: print eye aspect ratio every 30 frames
    frame_debug_counter = 0
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

                # Wink detection using eye aspect ratio for BOTH eyes
                # Left eye landmarks
                left_eye_top = landmarks[159]
                left_eye_bottom = landmarks[145]
                left_eye_left = landmarks[33]
                left_eye_right = landmarks[133]

                left_vertical_dist = abs(left_eye_top.y - left_eye_bottom.y)
                left_horizontal_dist = abs(left_eye_right.x - left_eye_left.x)
                left_ear = left_vertical_dist / left_horizontal_dist if left_horizontal_dist > 0 else 1.0

                # Right eye landmarks
                right_eye_top = landmarks[386]
                right_eye_bottom = landmarks[374]
                right_eye_left = landmarks[362]
                right_eye_right = landmarks[263]

                right_vertical_dist = abs(right_eye_top.y - right_eye_bottom.y)
                right_horizontal_dist = abs(right_eye_right.x - right_eye_left.x)
                right_ear = right_vertical_dist / right_horizontal_dist if right_horizontal_dist > 0 else 1.0

                # Debug: Print EAR periodically
                frame_debug_counter += 1
                if frame_debug_counter % 30 == 0:  # Every 1 second at 30fps
                    print(f"👁️ LEFT_EAR: {left_ear:.3f}, RIGHT_EAR: {right_ear:.3f} (thresh: {EYE_AR_THRESH}, closed_count: {eyes_closed_counter})", file=sys.stderr, flush=True)

                # Detect WINK: one eye closed, other eye open
                # Left eye closed, right eye open = left wink
                # Right eye closed, left eye open = right wink
                left_closed = left_ear < EYE_AR_THRESH
                right_closed = right_ear < EYE_AR_THRESH

                # Only trigger if exactly ONE eye is closed (wink, not blink)
                is_winking = (left_closed and not right_closed) or (right_closed and not left_closed)

                if is_winking:
                    eyes_closed_counter += 1
                    blink_counter += 1

                    # Trigger on sustained wink (3 consecutive frames)
                    if eyes_closed_counter == LONG_BLINK_THRESH and not long_blink_triggered:
                        long_blink_triggered = True
                        which_eye = "LEFT" if left_closed else "RIGHT"
                        print(f"😉 {which_eye} WINK TRIGGERED! (L:{left_ear:.3f} R:{right_ear:.3f})", file=sys.stderr, flush=True)
                        # Send blink event for screenshot using binary protocol
                        send_binary_blink(ema_x, ema_y)
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

                # Send gaze coordinates using binary protocol (17 bytes)
                send_binary_gaze(ema_x, ema_y)

            except Exception as e:
                continue

if __name__ == "__main__":
    main()
