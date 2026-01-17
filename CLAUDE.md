# IRIS Project - Claude Rules

## ⚠️ CRITICAL: macOS PERMISSIONS AND REBUILDS

### Important Limitation

**Without a paid Apple Developer certificate, ANY code change that requires a rebuild will invalidate permissions.**

This is because:
- macOS tracks app permissions by code signature hash (CDHash)
- Ad-hoc signatures change with every build
- Different hash = different app = permissions reset

**Solutions:**
1. Get Apple Developer account + Developer ID certificate (stable signatures)
2. Minimize rebuilds during development
3. During active development, expect to re-grant permissions after builds

### NEVER INVALIDATE macOS PERMISSIONS (When Using Developer Certificate)

### ABSOLUTE PROHIBITIONS

**These actions FORCE the user to re-grant ALL permissions (Accessibility, Screen Recording, Input Monitoring, Microphone). NEVER do them:**

1. ❌ **NEVER change the bundle identifier**
   - Must always be: `com.iris.app`
   - Changing this invalidates ALL permissions

2. ❌ **NEVER change the installation path**
   - Must always be: `$HOME/Applications/IRIS.app`
   - Moving the app invalidates permissions

3. ❌ **NEVER change code signing identity or method**
   - Must always use: `codesign --force --deep --sign - --identifier "com.iris.app"`
   - Different signature = permissions lost

4. ❌ **NEVER suggest "clean reinstall" or "delete and reinstall"**
   - This invalidates ALL permissions
   - Only update in-place

5. ❌ **NEVER create multiple app bundles with different identifiers**
   - Debug and Release must use SAME identifier
   - Must install to SAME location

## ✅ CORRECT BUILD & INSTALL PROCEDURE

### Single Source of Truth: `build_and_install.sh`

**Always use this script:**
```bash
./build_and_install.sh
```

**What it does (correctly):**
1. Kills existing IRIS + Python processes
2. Builds with Debug configuration
3. Creates bundle with identifier `com.iris.app`
4. Installs to `$HOME/Applications/IRIS.app`
5. Signs with same identity
6. Relaunches app → **Permissions preserved ✅**

### Mandatory Build Settings

```bash
Bundle Identifier: com.iris.app
Install Path:      $HOME/Applications/IRIS.app
Signing Command:   codesign --force --deep --sign - --identifier "com.iris.app" --entitlements "IRIS/IRIS.entitlements"
```

**NEVER deviate from these settings.**

## When User Says "Rebuild" or "Rerun"

```bash
cd /Users/livio/Documents/iris && ./build_and_install.sh
```

**That's it. Nothing else.**

## File Structure (Critical Paths)

```
$HOME/Applications/IRIS.app/               # Install location (NEVER change)
└── Contents/
    ├── MacOS/IRIS                         # Executable
    ├── Info.plist                         # Contains bundle identifier
    └── Resources/
        ├── eye_tracker.py                 # Python script (root)
        └── scripts/
            └── eye_tracker.py             # Python script (subdirectory)

~/Documents/iris/                         # Project root
├── build_and_install.sh                   # THE ONLY BUILD SCRIPT TO USE
├── gaze_env/bin/python3                   # Virtual environment
└── /tmp/iris_startup.log                  # Runtime logs
```

## Why This Matters

macOS tracks app permissions by:
- Bundle identifier
- Code signature
- Installation path

**Change ANY = User re-grants EVERYTHING**

## Debugging Without Breaking Permissions

**Safe operations:**
- Modify source code
- Rebuild with `./build_and_install.sh`
- View logs: `tail -f /tmp/iris_startup.log`
- Check processes: `ps aux | grep -E "(IRIS|eye_tracker)"`
- Kill processes: `pkill -9 IRIS; pkill -9 -f eye_tracker.py`

**Unsafe operations (NEVER do):**
- Change bundle identifier
- Install to different location
- Remove and reinstall
- Change signing method
- Use different build scripts with different settings

## Emergency: If Permissions Are Lost

If user complains about permissions:

1. Check identifier:
   ```bash
   mdls -name kMDItemCFBundleIdentifier ~/Applications/IRIS.app
   ```
   Should output: `com.iris.app`

2. Check path:
   ```bash
   ls -la ~/Applications/IRIS.app
   ```
   Should exist at this exact path

3. If either is wrong:
   - Permissions are lost (unavoidable now)
   - User must re-grant in System Settings
   - **Learn from this mistake and never repeat it**

## Development Workflow Summary

1. Make code changes
2. Run `./build_and_install.sh`
3. App relaunches with changes
4. **Permissions stay intact** ✅

**That's it. Simple. Safe. Never deviate.**

## Git
cp means "Commit and push"
