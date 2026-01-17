#!/bin/bash
set -e

echo "🔨 Building IRIS with Swift Package Manager..."
swift build -c release

BUILD_DIR=".build/arm64-apple-macosx/release"
APP_NAME="IRIS"
BUNDLE_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creating app bundle structure..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "📄 Copying executable..."
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

echo "📄 Copying Info.plist..."
cp "IRIS/Info.plist" "${CONTENTS_DIR}/Info.plist"

echo "📄 Copying Python script..."
if [ -f "eye_tracker.py" ]; then
    cp "eye_tracker.py" "${RESOURCES_DIR}/eye_tracker.py"
fi

echo "🔐 Signing app bundle with entitlements..."
codesign --force --deep --sign - --entitlements "IRIS/IRIS.entitlements" "${BUNDLE_DIR}"

echo "✅ App bundle created at: ${BUNDLE_DIR}"
echo ""
echo "To run the app:"
echo "  open ${BUNDLE_DIR}"
echo ""
echo "Or from command line:"
echo "  ${MACOS_DIR}/${APP_NAME}"
