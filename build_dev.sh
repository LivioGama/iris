#!/bin/bash
# Build IRIS with development mode colors enabled
# Usage: ./build_dev.sh

set -e

echo "🎨 Building IRIS in DEVELOPMENT MODE (vibrant colors)"
echo ""

# Temporarily add LSEnvironment to Info.plist
INFOPLIST="IRIS/Info.plist"
BACKUP="IRIS/Info.plist.backup"

# Backup original
cp "$INFOPLIST" "$BACKUP"

# Add LSEnvironment before closing dict
sed -i '' '/<key>NSPrincipalClass<\/key>/a\
    <key>LSEnvironment</key>\
    <dict>\
        <key>IRIS_DEVELOPMENT_MODE</key>\
        <string>true</string>\
    </dict>
' "$INFOPLIST"

# Build
./build_and_install.sh

# Restore original
mv "$BACKUP" "$INFOPLIST"

echo ""
echo "✅ Development mode build complete!"
echo "   Colors: Vibrant cyan/purple (development mode)"
echo "   To build production mode: ./build_and_install.sh"
