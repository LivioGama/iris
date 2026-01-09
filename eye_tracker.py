#!/usr/bin/env python3
import sys
import json
import cv2
import os
from pathlib import Path

os.environ["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] = "YES"

from eyetrax import GazeEstimator
from eyetrax.calibration import run_9_point_calibration, run_5_point_calibration

MODEL_PATH = Path(__file__).parent / "gaze_model.pkl"

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
    
    estimator = GazeEstimator(model_name="ridge")
    
    if MODEL_PATH.exists():
        print(json.dumps({"status": "loading"}), flush=True)
        estimator.load_model(str(MODEL_PATH))
        print(json.dumps({"status": "calibrated"}), flush=True)
    else:
        print(json.dumps({"status": "calibrating"}), flush=True)
        run_5_point_calibration(estimator)
        estimator.save_model(str(MODEL_PATH))
        print(json.dumps({"status": "calibrated"}), flush=True)
    
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    
    ema_x, ema_y = screen_width / 2, screen_height / 2
    ema_alpha = 0.15
    
    while True:
        ret, frame = cap.read()
        if not ret:
            continue
        
        try:
            features, blink = estimator.extract_features(frame)
            
            if features is not None and not blink:
                pred = estimator.predict([features])[0]
                x, y = float(pred[0]), float(pred[1])
                
                x = max(0, min(screen_width, x))
                y = max(0, min(screen_height, y))
                
                ema_x += (x - ema_x) * ema_alpha
                ema_y += (y - ema_y) * ema_alpha
                
                print(json.dumps({
                    "x": ema_x,
                    "y": ema_y,
                    "h": ema_x / screen_width,
                    "v": ema_y / screen_height,
                    "blink": False
                }), flush=True)
            elif blink:
                print(json.dumps({
                    "x": ema_x,
                    "y": ema_y,
                    "h": ema_x / screen_width,
                    "v": ema_y / screen_height,
                    "blink": True
                }), flush=True)
                
        except Exception as e:
            print(json.dumps({"error": str(e)}), flush=True)
            continue

if __name__ == "__main__":
    main()
