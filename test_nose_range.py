#!/usr/bin/env python3
"""Test script to see actual nose position values"""
import cv2
import mediapipe as mp
import time

mp_face_mesh = mp.solutions.face_mesh

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

print("Move your head to the EXTREME positions and watch the values:")
print("nose_x: horizontal (left/right)")
print("nose_y: vertical (up/down)")
print("\nPress Ctrl+C to exit\n")

with mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
) as face_mesh:

    min_x = 1.0
    max_x = 0.0
    min_y = 1.0
    max_y = 0.0

    while True:
        ret, frame = cap.read()
        if not ret:
            continue

        frame = cv2.flip(frame, 1)
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(rgb)

        if results.multi_face_landmarks:
            landmarks = results.multi_face_landmarks[0].landmark

            nose = landmarks[4]
            forehead = landmarks[10]
            nose_x = nose.x
            nose_y = forehead.y

            min_x = min(min_x, nose_x)
            max_x = max(max_x, nose_x)
            min_y = min(min_y, nose_y)
            max_y = max(max_y, nose_y)

            x_range = max_x - min_x
            y_range = max_y - min_y

            print(f"\rCurrent: X={nose_x:.4f} Y={nose_y:.4f} | Range: X={min_x:.4f}-{max_x:.4f} ({x_range:.4f}) Y={min_y:.4f}-{max_y:.4f} ({y_range:.4f})", end="")

        time.sleep(0.033)  # ~30fps

cap.release()
