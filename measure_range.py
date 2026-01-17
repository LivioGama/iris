#!/usr/bin/env python3
import cv2
import os
import mediapipe as mp

os.environ["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"

mp_face_mesh = mp.solutions.face_mesh

print("=== MEASURING YOUR HEAD MOVEMENT RANGE ===")
print("Move your head to ALL FOUR CORNERS and CENTER for 10 seconds")
print("Starting in 3 seconds...\n")

import time
time.sleep(3)

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

nose_x_values = []
nose_y_values = []

with mp_face_mesh.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
) as face_mesh:

    frame_count = 0
    max_frames = 300  # 10 seconds at 30fps

    while frame_count < max_frames:
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
            nose = landmarks[4]
            forehead = landmarks[10]

            nose_x_values.append(nose.x)
            nose_y_values.append(forehead.y)

            frame_count += 1
            if frame_count % 30 == 0:
                print(f"{frame_count // 30} seconds...")

        except Exception as e:
            continue

if nose_x_values and nose_y_values:
    print(f"\n=== YOUR ACTUAL RANGE ===")
    print(f"nose_x_min = {min(nose_x_values):.4f}")
    print(f"nose_x_max = {max(nose_x_values):.4f}")
    print(f"nose_y_min = {min(nose_y_values):.4f}")
    print(f"nose_y_max = {max(nose_y_values):.4f}")
    print(f"\nUse these values in eye_tracker.py!")
