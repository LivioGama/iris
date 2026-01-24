#!/usr/bin/env python3
"""
Gaze calibration tool for IRIS
Measures head position ranges for MacBook + External monitor
"""
import cv2
import mediapipe as mp
import json
import sys
import time
import os

os.environ["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"

mp_face_mesh = mp.solutions.face_mesh

def calibrate():
    print("=== IRIS Gaze Calibration (Multi-Screen) ===")
    print("\nThis will measure your head position ranges for BOTH screens.")
    print("\nYou'll be asked to look at:")
    print("  - 5 positions on your MacBook screen")
    print("  - 5 positions on your External monitor")
    print("\nStarting in 3 seconds...")
    time.sleep(3)

    cap = cv2.VideoCapture(0, cv2.CAP_AVFOUNDATION)
    if not cap.isOpened():
        print("\nERROR: Could not open camera!")
        print("Please ensure no other application (like the IRIS app) is using the camera.")
        print("Try running: pkill IRIS")
        sys.exit(1)

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    # Collect samples
    nose_x_values = []
    nose_y_values = []

    print("\n" + "="*60)
    print("STEP 1: CALIBRATE MACBOOK SCREEN")
    print("="*60)

    macbook_positions = [
        "TOP-LEFT corner of MACBOOK",
        "TOP-RIGHT corner of MACBOOK",
        "BOTTOM-LEFT corner of MACBOOK",
        "BOTTOM-RIGHT corner of MACBOOK",
        "CENTER of MACBOOK"
    ]

    print("\n" + "="*60)
    print("STEP 2: CALIBRATE EXTERNAL MONITOR")
    print("="*60)

    external_positions = [
        "TOP-LEFT corner of EXTERNAL MONITOR",
        "TOP-RIGHT corner of EXTERNAL MONITOR",
        "BOTTOM-LEFT corner of EXTERNAL MONITOR",
        "BOTTOM-RIGHT corner of EXTERNAL MONITOR",
        "CENTER of EXTERNAL MONITOR"
    ]

    all_positions = macbook_positions + external_positions

    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:

        for i, position in enumerate(all_positions):
            if i == 5:
                print("\n" + "="*60)
                print("NOW SWITCHING TO EXTERNAL MONITOR")
                print("="*60)
                time.sleep(2)

            print(f"\n>>> Look at the {position} and hold still...")
            time.sleep(1.5)

            # Collect 30 samples (1 second at 30fps)
            samples_x = []
            samples_y = []

            for j in range(30):
                ret, frame = cap.read()
                if not ret:
                    continue

                frame = cv2.flip(frame, 1)
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = face_mesh.process(rgb)

                if results.multi_face_landmarks:
                    landmarks = results.multi_face_landmarks[0].landmark

                    # Use nose for horizontal, forehead for vertical
                    nose = landmarks[4]
                    forehead = landmarks[10]
                    nose_x = nose.x
                    nose_y = forehead.y

                    samples_x.append(nose_x)
                    samples_y.append(nose_y)

            if samples_x and samples_y:
                avg_x = sum(samples_x) / len(samples_x)
                avg_y = sum(samples_y) / len(samples_y)

                nose_x_values.append(avg_x)
                nose_y_values.append(avg_y)

                print(f"    Captured: nose_x={avg_x:.4f}, nose_y={avg_y:.4f}")
            else:
                print("    ERROR: No face detected!")
                cap.release()
                return

    cap.release()

    # Calculate ranges with padding
    if len(nose_x_values) >= 10 and len(nose_y_values) >= 10:
        # Split values for MacBook (first 5) and External (last 5)
        macbook_x = nose_x_values[:5]
        macbook_y = nose_y_values[:5]
        external_x = nose_x_values[5:]
        external_y = nose_y_values[5:]

        # Calculate combined ranges (all screens)
        nose_x_min = min(nose_x_values)
        nose_x_max = max(nose_x_values)
        nose_y_min = min(nose_y_values)
        nose_y_max = max(nose_y_values)

        # Add 10% padding for easier tracking
        x_padding = (nose_x_max - nose_x_min) * 0.1
        y_padding = (nose_y_max - nose_y_min) * 0.1

        nose_x_min -= x_padding
        nose_x_max += x_padding
        nose_y_min -= y_padding
        nose_y_max += y_padding

        print("\n" + "="*60)
        print("CALIBRATION RESULTS - COMBINED (MacBook + External)")
        print("="*60)
        print(f"\nX range (horizontal): {nose_x_min:.4f} to {nose_x_max:.4f}")
        print(f"Y range (vertical):   {nose_y_min:.4f} to {nose_y_max:.4f}")
        print(f"\nX range span: {nose_x_max - nose_x_min:.4f}")
        print(f"Y range span: {nose_y_max - nose_y_min:.4f}")

        # Show individual screen ranges
        print("\n" + "-"*60)
        print("MacBook Screen Only:")
        print(f"  X: {min(macbook_x):.4f} to {max(macbook_x):.4f} (span: {max(macbook_x)-min(macbook_x):.4f})")
        print(f"  Y: {min(macbook_y):.4f} to {max(macbook_y):.4f} (span: {max(macbook_y)-min(macbook_y):.4f})")

        print("\nExternal Monitor Only:")
        print(f"  X: {min(external_x):.4f} to {max(external_x):.4f} (span: {max(external_x)-min(external_x):.4f})")
        print(f"  Y: {min(external_y):.4f} to {max(external_y):.4f} (span: {max(external_y)-min(external_y):.4f})")

        print("\n" + "="*60)
        print("UPDATE eye_tracker.py with COMBINED values:")
        print("="*60)
        print(f"nose_x_min, nose_x_max = {nose_x_min:.4f}, {nose_x_max:.4f}")
        print(f"nose_y_min, nose_y_max = {nose_y_min:.4f}, {nose_y_max:.4f}")
        print("="*60)

        # Save to file
        with open('/tmp/iris_calibration.txt', 'w') as f:
            f.write(f"# Combined calibration (MacBook + External)\n")
            f.write(f"nose_x_min, nose_x_max = {nose_x_min:.4f}, {nose_x_max:.4f}\n")
            f.write(f"nose_y_min, nose_y_max = {nose_y_min:.4f}, {nose_y_max:.4f}\n")
            f.write(f"\n# MacBook only:\n")
            f.write(f"# X: {min(macbook_x):.4f} to {max(macbook_x):.4f}\n")
            f.write(f"# Y: {min(macbook_y):.4f} to {max(macbook_y):.4f}\n")
            f.write(f"\n# External only:\n")
            f.write(f"# X: {min(external_x):.4f} to {max(external_x):.4f}\n")
            f.write(f"# Y: {min(external_y):.4f} to {max(external_y):.4f}\n")

        print("\nCalibration saved to: /tmp/iris_calibration.txt")
    else:
        print("\nERROR: Insufficient calibration data collected!")

if __name__ == "__main__":
    try:
        calibrate()
    except KeyboardInterrupt:
        print("\n\nCalibration cancelled.")
        sys.exit(0)
