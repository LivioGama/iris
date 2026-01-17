#!/bin/bash
export GEMINI_API_KEY="REDACTED_GOOGLE_API_KEY_1"

pkill -9 IRIS 2>/dev/null
swift build -c release
codesign --force --sign - --entitlements IRIS/IRIS.entitlements .build/release/IRIS
.build/release/IRIS
