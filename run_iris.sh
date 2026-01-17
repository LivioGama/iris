#!/bin/bash

# Set your Gemini API key here
export GEMINI_API_KEY="AIzaSyBctAFNLmRX5MiI8FlPw0mjCb2vKubzUOM"

# Kill any existing IRIS processes
pkill -9 IRIS
pkill -9 -f eye_tracker.py
sleep 2

# Launch IRIS
cd "$(dirname "$0")"
.build/debug/IRIS
