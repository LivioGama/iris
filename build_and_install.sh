#!/bin/bash
set -e

# === Incremental Build Script ===
# Skips steps when nothing changed to avoid killing/restarting unnecessarily.
#
# Logic:
#   1. Check if Rust sources changed → rebuild Rust lib (or skip)
#   2. Check if Swift sources or Rust lib changed → rebuild Swift (or skip)
#   3. If final binary changed → kill app, re-bundle, re-sign, relaunch
#   4. If nothing changed → do nothing

APP_NAME="IRIS"
BUILD_DIR=".build/arm64-apple-macosx/debug"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INSTALL_PATH="$HOME/Applications/${APP_NAME}.app"
SIGNING_IDENTITY="Apple Development: Livio Gamassia (7AU6G3886P)"
HASH_DIR=".build/hashes"

mkdir -p "$HASH_DIR"

# --- Utility: compute a content hash for a set of files ---
compute_hash() {
    find "$@" -type f \( -name "*.rs" -o -name "*.toml" \) 2>/dev/null | sort | xargs cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1
}

compute_swift_hash() {
    # Hash all Swift sources + Package.swift + the Rust static lib
    {
        find IRIS IRISGaze IRISCore IRISVision IRISNetwork IRISMedia -type f -name "*.swift" 2>/dev/null | sort | xargs cat 2>/dev/null
        cat Package.swift 2>/dev/null
        cat libs/libiris_gaze.a 2>/dev/null | shasum -a 256
    } | shasum -a 256 | cut -d' ' -f1
}

# ============================================================
# STEP 1: Rust build (skip if sources unchanged)
# ============================================================
RUST_CHANGED=false
if [ -d "iris-gaze-rs" ]; then
    RUST_HASH=$(compute_hash iris-gaze-rs/src iris-gaze-rs/Cargo.toml)
    OLD_RUST_HASH=$(cat "$HASH_DIR/rust.hash" 2>/dev/null || echo "")

    if [ "$RUST_HASH" != "$OLD_RUST_HASH" ]; then
        echo "🦀 Rust sources changed, rebuilding..."
        cd iris-gaze-rs
        FEATURES=""
        if [ "$USE_MEDIAPIPE" = "1" ]; then
            echo "🔧 Building with MediaPipe feature..."
            FEATURES="--features mediapipe"
        fi

        RUSTC_WRAPPER="" cargo build --release --target aarch64-apple-darwin $FEATURES

        mkdir -p ../libs
        cp target/aarch64-apple-darwin/release/libiris_gaze.a ../libs/

        if [ -f "include/iris_gaze.h" ]; then
            cp include/iris_gaze.h ../IRISGaze/Sources/Bridge/
        fi

        cd ..
        echo "$RUST_HASH" > "$HASH_DIR/rust.hash"
        RUST_CHANGED=true
        echo "✅ Rust library rebuilt"
    else
        echo "🦀 Rust sources unchanged, skipping rebuild"
    fi
fi

# ============================================================
# STEP 2: Swift build (skip if sources + Rust lib unchanged)
# ============================================================
SWIFT_HASH=$(compute_swift_hash)
OLD_SWIFT_HASH=$(cat "$HASH_DIR/swift.hash" 2>/dev/null || echo "")
SWIFT_CHANGED=false

if [ "$SWIFT_HASH" != "$OLD_SWIFT_HASH" ] || [ "$RUST_CHANGED" = true ]; then
    echo "🔨 Building IRIS with Swift Package Manager (Debug)..."
    swift build -c debug
    echo "$SWIFT_HASH" > "$HASH_DIR/swift.hash"
    SWIFT_CHANGED=true
    echo "✅ Swift build complete"
else
    echo "🔨 Swift sources unchanged, skipping rebuild"
fi

# ============================================================
# STEP 3: Check if the final binary actually changed
# ============================================================
NEW_BINARY="${BUILD_DIR}/${APP_NAME}"
INSTALLED_BINARY="${INSTALL_PATH}/Contents/MacOS/${APP_NAME}"

if [ "$SWIFT_CHANGED" = false ] && [ -f "$INSTALLED_BINARY" ]; then
    echo "✅ Nothing changed, app is up to date!"
    # Make sure it's running
    if ! pgrep -x "IRIS" > /dev/null; then
        echo "🚀 App not running, launching..."
        open "${INSTALL_PATH}"
    fi
    exit 0
fi

# Binary changed — need to kill, bundle, sign, relaunch
# ============================================================
# STEP 4: Kill existing app (graceful then force)
# ============================================================
if pgrep -x "IRIS" > /dev/null; then
    echo "🛑 Stopping existing IRIS instance..."
    pkill -x "IRIS" 2>/dev/null || true
    sleep 0.5
    pkill -9 -x "IRIS" 2>/dev/null || true
fi

pkill -9 -f "eye_tracker.py" 2>/dev/null || true
pkill -9 -f "face_mesh_server.py" 2>/dev/null || true

# Wait for camera to be fully released by macOS
sleep 2

# ============================================================
# STEP 5: Bundle, sign, install
# ============================================================
echo "📦 Creating app bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}/scripts"

cp "${NEW_BINARY}" "${MACOS_DIR}/${APP_NAME}"
cp "IRIS/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Copy app icon if it exists
if [ -f "IRIS/Resources/AppIcon.icns" ]; then
    cp "IRIS/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

if [ -f "eye_tracker.py" ]; then
    cp "eye_tracker.py" "${RESOURCES_DIR}/scripts/eye_tracker.py"
    cp "eye_tracker.py" "${RESOURCES_DIR}/eye_tracker.py"
fi

echo "🔐 Signing app bundle..."
codesign --force --deep --sign "$SIGNING_IDENTITY" \
    --identifier "com.iris.app" \
    --entitlements "IRIS/IRIS.entitlements" \
    --timestamp \
    "${BUNDLE_DIR}"

echo "📥 Installing to ${INSTALL_PATH}..."
mkdir -p "$HOME/Applications"

if [ -d "${INSTALL_PATH}" ]; then
    rsync -a --delete "${BUNDLE_DIR}/" "${INSTALL_PATH}/"
else
    cp -R "${BUNDLE_DIR}" "${INSTALL_PATH}"
fi

echo "🔐 Re-signing installed app..."
codesign --force --deep --sign "$SIGNING_IDENTITY" \
    --identifier "com.iris.app" \
    --entitlements "IRIS/IRIS.entitlements" \
    --timestamp \
    "${INSTALL_PATH}"

# ============================================================
# STEP 6: Launch
# ============================================================
echo "🚀 Launching IRIS..."
open "${INSTALL_PATH}"

echo ""
echo "✅ IRIS rebuilt and relaunched successfully!"
echo "Debug logs: tail -f /tmp/iris_startup.log"
