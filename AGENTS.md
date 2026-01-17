# IRIS Project Guidelines

## macOS Permissions and Code Signing

When working on the IRIS project, be aware that macOS tracks app permissions by code signature hash (CDHash). Without a paid Apple Developer certificate, any code change that requires a rebuild will invalidate permissions because ad-hoc signatures change with every build, resulting in a different hash that macOS treats as a different app.

Solutions include obtaining an Apple Developer account with a Developer ID certificate for stable signatures, minimizing rebuilds during development, or expecting to re-grant permissions after builds during active development.

## Critical Constraints - Never Violate These

The following actions will force the user to re-grant ALL permissions (Accessibility, Screen Recording, Input Monitoring, Microphone) and must never be done:

1. Never change the bundle identifier - it must always be `com.iris.app`
2. Never change the installation path - it must always be `$HOME/Applications/IRIS.app`
3. Never change code signing identity or method - must always use `codesign --force --deep --sign - --identifier "com.iris.app"`
4. Never suggest "clean reinstall" or "delete and reinstall" as this invalidates all permissions
5. Never create multiple app bundles with different identifiers - Debug and Release must use the same identifier and install to the same location

## Build and Install Procedure

Always use the single build script: `./build_and_install.sh`

This script correctly:
1. Kills existing IRIS and Python processes
2. Builds with Debug configuration
3. Creates bundle with identifier `com.iris.app`
4. Installs to `$HOME/Applications/IRIS.app`
5. Signs with the same identity
6. Relaunches the app with permissions preserved

Mandatory build settings:
- Bundle Identifier: `com.iris.app`
- Install Path: `$HOME/Applications/IRIS.app`
- Signing Command: `codesign --force --deep --sign - --identifier "com.iris.app" --entitlements "IRIS/IRIS.entitlements"`

When the user says "rebuild" or "rerun", execute: `cd /Users/livio/Documents/iris && ./build_and_install.sh`

## File Structure

Critical paths:
- `$HOME/Applications/IRIS.app/` - Installation location (never change)
  - `Contents/MacOS/IRIS` - Executable
  - `Contents/Info.plist` - Contains bundle identifier
  - `Contents/Resources/eye_tracker.py` - Python script (root)
  - `Contents/Resources/scripts/eye_tracker.py` - Python script (subdirectory)
- `~/Documents/iris/` - Project root
  - `build_and_install.sh` - The only build script to use
  - `gaze_env/bin/python3` - Virtual environment
- `/tmp/iris_startup.log` - Runtime logs

## Safe Debugging Operations

Safe operations that do not break permissions:
- Modify source code
- Rebuild with `./build_and_install.sh`
- View logs: `tail -f /tmp/iris_startup.log`
- Check processes: `ps aux | grep -E "(IRIS|eye_tracker)"`
- Kill processes: `pkill -9 IRIS; pkill -9 -f eye_tracker.py`

Unsafe operations to never perform:
- Change bundle identifier
- Install to different location
- Remove and reinstall
- Change signing method
- Use different build scripts with different settings

## If Permissions Are Lost

If the user reports permission issues:

1. Check the identifier: `mdls -name kMDItemCFBundleIdentifier ~/Applications/IRIS.app` (should output `com.iris.app`)
2. Check the path: `ls -la ~/Applications/IRIS.app` (should exist at this exact path)
3. If either is wrong, permissions are lost and the user must re-grant them in System Settings

## Development Workflow

1. Make code changes
2. Run `./build_and_install.sh`
3. App relaunches with changes
4. Permissions stay intact

## Git Conventions

"cp" means "commit and push"
