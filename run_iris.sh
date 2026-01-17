#!/bin/bash

# SECURITY NOTE: API key is now stored securely in macOS Keychain.
# To set up your API key, run: ./scripts/setup_api_key.sh
# The application will automatically retrieve it from the Keychain.

# Kill any existing IRIS processes
pkill -9 IRIS
pkill -9 -f eye_tracker.py
sleep 2

# Launch IRIS
cd "$(dirname "$0")"
.build/debug/IRIS
