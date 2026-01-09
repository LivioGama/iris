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
    
    nose_x_min, nose_x_max = 0.47, 0.57
    nose_y_min, nose_y_max = 0.45, 0.52
    
    ema_x, ema_y = screen_width / 2, screen_height / 2
    ema_nose_x, ema_nose_y = 0.5, 0.5
    
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
                
                nose = landmarks[4]
                nose_x, nose_y = nose.x, nose.y
                
                ema_nose_x += (nose_x - ema_nose_x) * 0.2
                ema_nose_y += (nose_y - ema_nose_y) * 0.2
                
                h_norm = (ema_nose_x - nose_x_min) / (nose_x_max - nose_x_min)
                v_norm = (ema_nose_y - nose_y_min) / (nose_y_max - nose_y_min)
                
                h_norm = max(0, min(1, h_norm))
                v_norm = max(0, min(1, v_norm))
                
                target_x = h_norm * screen_width
                target_y = v_norm * screen_height
                
                ema_x += (target_x - ema_x) * 0.15
                ema_y += (target_y - ema_y) * 0.15
                
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
