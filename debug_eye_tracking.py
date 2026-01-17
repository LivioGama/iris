#!/usr/bin/env python3
import sys
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
    args = parser.parse_args()

    print("=== EYE TRACKING DEBUG ===")
    print(f"Using: {args.eye} eye")
    print("\nPlease look at each corner for 3 seconds:")
    print("1. TOP-LEFT corner")
    print("2. TOP-RIGHT corner")
    print("3. BOTTOM-LEFT corner")
    print("4. BOTTOM-RIGHT corner")
    print("5. CENTER\n")
    print("Press Ctrl+C when done\n")

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:

        frame_count = 0
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

                if args.eye == 'left':
                    eye_center = landmarks[468]
                    eye_left = landmarks[33]
                    eye_right = landmarks[133]
                    eye_top = landmarks[159]
                    eye_bottom = landmarks[145]
                else:
                    eye_center = landmarks[473]
                    eye_left = landmarks[362]
                    eye_right = landmarks[263]
                    eye_top = landmarks[386]
                    eye_bottom = landmarks[374]

                eye_width = abs(eye_right.x - eye_left.x)
                eye_height = abs(eye_bottom.y - eye_top.y)

                if eye_width > 0:
                    iris_x_rel = (eye_center.x - eye_left.x) / eye_width
                else:
                    iris_x_rel = 0.5

                if eye_height > 0:
                    iris_y_rel = (eye_center.y - eye_top.y) / eye_height
                else:
                    iris_y_rel = 0.5

                frame_count += 1
                if frame_count % 10 == 0:  # Print every 10 frames
                    print(f"iris_x: {iris_x_rel:.4f}  |  iris_y: {iris_y_rel:.4f}")

            except Exception as e:
                print(f"Error: {e}")
                continue

if __name__ == "__main__":
    main()
