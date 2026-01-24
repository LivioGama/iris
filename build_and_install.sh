#!/bin/bash
set -e

# Kill existing processes FIRST
if pgrep -x "IRIS" > /dev/null; then
    echo "🛑 Stopping existing IRIS instance..."
    pkill -9 -x "IRIS"
fi

if pgrep -f "eye_tracker.py" > /dev/null; then
    echo "🛑 Stopping Python eye tracker processes..."
    pkill -9 -f "eye_tracker.py"
fi

# Wait for processes to terminate
sleep 1

# Build Rust gaze library first
echo "🦀 Building Rust gaze library..."
if [ -d "iris-gaze-rs" ]; then
    cd iris-gaze-rs
    FEATURES=""
    if [ "$USE_MEDIAPIPE" = "1" ]; then
        echo "🔧 Building with MediaPipe feature..."
        if [ -z "$MEDIAPIPE_DIR" ]; then
            echo "❌ MEDIAPIPE_DIR is required when USE_MEDIAPIPE=1"
            exit 1
        fi
        if [ -z "$MEDIAPIPE_LINK_LIBS" ]; then
            echo "❌ MEDIAPIPE_LINK_LIBS is required when USE_MEDIAPIPE=1"
            exit 1
        fi
        FEATURES="--features mediapipe"
    fi

    cargo build --release --target aarch64-apple-darwin $FEATURES 2>&1 | tail -10

    # Copy static library to libs directory
    mkdir -p ../libs
    cp target/aarch64-apple-darwin/release/libiris_gaze.a ../libs/

    # Copy generated header to Swift bridge
    if [ -f "include/iris_gaze.h" ]; then
        cp include/iris_gaze.h ../IRISGaze/Sources/Bridge/
    fi

    cd ..
    echo "✅ Rust library built successfully"
else
    echo "⚠️ Rust crate not found, skipping Rust build"
fi

# Build configuration
echo "🔨 Building IRIS with Swift Package Manager (Debug)..."
swift build -c debug

BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_NAME="IRIS"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INSTALL_PATH="$HOME/Applications/${APP_NAME}.app"

echo "📦 Creating app bundle structure..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}/scripts"

echo "📄 Copying executable..."
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

echo "📄 Copying Info.plist..."
cp "IRIS/Info.plist" "${CONTENTS_DIR}/Info.plist"

echo "📄 Copying Python script..."
if [ -f "eye_tracker.py" ]; then
    cp "eye_tracker.py" "${RESOURCES_DIR}/scripts/eye_tracker.py"
    cp "eye_tracker.py" "${RESOURCES_DIR}/eye_tracker.py"
fi

echo "🔐 Signing app bundle with Developer ID..."
# Use the first available Apple Development certificate
SIGNING_IDENTITY="Apple Development: Livio Gamassia (7AU6G3886P)"
codesign --force --deep --sign "$SIGNING_IDENTITY" \
    --identifier "com.iris.app" \
    --entitlements "IRIS/IRIS.entitlements" \
    --timestamp \
    "${BUNDLE_DIR}"

echo "📥 Installing to ${INSTALL_PATH}..."
mkdir -p "$HOME/Applications"

# Use rsync to preserve metadata and only update changed files
# This helps maintain app identity and permissions
if [ -d "${INSTALL_PATH}" ]; then
    echo "   Updating existing app bundle..."
    rsync -a --delete "${BUNDLE_DIR}/" "${INSTALL_PATH}/"
else
    echo "   Creating new app bundle..."
    cp -R "${BUNDLE_DIR}" "${INSTALL_PATH}"
fi

echo "🔐 Re-signing installed app with Developer ID..."
codesign --force --deep --sign "$SIGNING_IDENTITY" \
    --identifier "com.iris.app" \
    --entitlements "IRIS/IRIS.entitlements" \
    --timestamp \
    "${INSTALL_PATH}"

echo "🚀 Launching IRIS..."
open "${INSTALL_PATH}"

echo ""
echo "✅ IRIS rebuilt and relaunched successfully!"
echo ""
echo "Debug logs: tail -f /tmp/iris_startup.log"
