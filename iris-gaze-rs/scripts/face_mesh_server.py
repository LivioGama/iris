#!/usr/bin/env python3
"""
Lightweight MediaPipe face mesh server for IRIS.
Outputs face landmarks as JSON lines to stdout.
Rust reads these and handles gaze calculation.
"""

import sys
import json
import cv2
import mediapipe as mp

def main():
    mp_face_mesh = mp.solutions.face_mesh

    # Open camera (index 1 for MacBook camera)
    cap = cv2.VideoCapture(1)
    if not cap.isOpened():
        cap = cv2.VideoCapture(0)

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)

    print(json.dumps({"status": "ready"}), flush=True)

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

            # Mirror the frame (like Python eye_tracker.py)
            frame = cv2.flip(frame, 1)

            # Convert to RGB for MediaPipe
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(rgb)

            if results.multi_face_landmarks:
                landmarks = results.multi_face_landmarks[0].landmark

                # Output key landmarks for gaze tracking
                # Nose tip (4), Forehead (10), Eye corners for EAR
                output = {
                    "landmarks": {
                        # Nose and forehead for gaze
                        "4": {"x": landmarks[4].x, "y": landmarks[4].y, "z": landmarks[4].z},
                        "10": {"x": landmarks[10].x, "y": landmarks[10].y, "z": landmarks[10].z},
                        # Left eye for EAR
                        "33": {"x": landmarks[33].x, "y": landmarks[33].y},
                        "133": {"x": landmarks[133].x, "y": landmarks[133].y},
                        "159": {"x": landmarks[159].x, "y": landmarks[159].y},
                        "145": {"x": landmarks[145].x, "y": landmarks[145].y},
                        # Right eye for EAR
                        "362": {"x": landmarks[362].x, "y": landmarks[362].y},
                        "263": {"x": landmarks[263].x, "y": landmarks[263].y},
                        "386": {"x": landmarks[386].x, "y": landmarks[386].y},
                        "374": {"x": landmarks[374].x, "y": landmarks[374].y},
                    }
                }
                print(json.dumps(output), flush=True)
            else:
                print(json.dumps({"landmarks": None}), flush=True)

if __name__ == "__main__":
    main()
