#!/bin/bash
pkill -9 IRIS 2>/dev/null
swift build -c release
codesign --force --sign - --entitlements IRIS/IRIS.entitlements .build/release/IRIS
.build/release/IRIS
