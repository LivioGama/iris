#!/bin/bash

# SECURITY NOTE: API key is now stored securely in macOS Keychain.
# To set up your API key, run: ./scripts/setup_api_key.sh
# The application will automatically retrieve it from the Keychain.

pkill -9 IRIS 2>/dev/null
swift build -c release
codesign --force --sign - --entitlements IRIS/IRIS.entitlements .build/release/IRIS
.build/release/IRIS
