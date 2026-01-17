# IRIS Verification Scripts

Automated continuous build and testing system for IRIS development.

## Overview

This directory contains scripts to verify IRIS after each development phase, ensuring:
- ✅ Build succeeds with no errors
- ✅ App launches without crashes
- ✅ Performance targets are met (30 FPS)
- ✅ No memory leaks
- ✅ All features remain functional

## Quick Start

### After completing any phase:

```bash
./scripts/verify_phase.sh "Phase X: Description"
```

This runs all verification checks and reports success/failure.

## Available Scripts

### 1. `verify_phase.sh` - Master Verification Script
**Primary script for phase completion verification.**

```bash
# Full verification (recommended)
./scripts/verify_phase.sh "Phase 2: Module Structure"

# Quick mode (skip performance/memory checks)
./scripts/verify_phase.sh "Phase 2: Module Structure" false true

# Skip build, quick mode
./scripts/verify_phase.sh "Phase 2: Module Structure" true true
```

**Parameters:**
- `$1` - Phase name/description (required)
- `$2` - Skip build? (default: false)
- `$3` - Quick mode? (default: false)

**What it does:**
1. Runs build verification
2. Runs smoke tests
3. Checks performance (unless quick mode)
4. Checks memory (unless quick mode)
5. Generates summary report

---

### 2. `build_verify.sh` - Build Verification
**Verifies that the project compiles successfully.**

```bash
./scripts/build_verify.sh
```

**Checks:**
- ✓ Clean build succeeds
- ✓ No compilation errors
- ✓ No import conflicts
- ✓ All modules compile
- ✓ Warnings are reported (but don't fail)

**Exit codes:**
- `0` - Build successful
- `1` - Build failed

---

### 3. `smoke_test.sh` - Smoke Testing
**Validates basic functionality and startup.**

```bash
./scripts/smoke_test.sh
```

**Checks:**
- ✓ Binary exists
- ✓ App launches successfully
- ✓ No crashes on startup
- ✓ All modules initialize
- ✓ No fatal errors in logs

**Exit codes:**
- `0` - Tests passed
- `1` - Tests failed

---

### 4. `performance_check.sh` - Performance Verification
**Monitors performance metrics.**

```bash
./scripts/performance_check.sh
```

**Checks:**
- ✓ CPU usage reasonable
- ✓ Memory footprint acceptable
- ✓ Fast startup time (< 3s)
- ✓ No responsiveness issues
- ✓ FPS targets (informational)

**Exit codes:**
- `0` - Performance acceptable
- `1` - Performance issues detected

---

### 5. `memory_check.sh` - Memory Leak Detection
**Detects memory leaks and growth issues.**

```bash
./scripts/memory_check.sh
```

**Checks:**
- ✓ No memory leaks (using `leaks` tool)
- ✓ Memory growth within bounds
- ✓ Conversation history bounded
- ✓ No excessive allocations

**Exit codes:**
- `0` - No memory issues
- `1` - Memory leaks or excessive growth

---

## Usage Examples

### During Active Development
```bash
# Quick check after making changes
./scripts/build_verify.sh
```

### After Completing a Feature
```bash
# Quick verification
./scripts/verify_phase.sh "Feature: User Authentication" false true
```

### Before Committing
```bash
# Full verification
./scripts/verify_phase.sh "Feature: Element Detection"
```

### Critical Checkpoints

**After Phase 2: Module Structure**
```bash
./scripts/verify_phase.sh "Phase 2: Module Structure"
# Ensures all modules build and link correctly
```

**After Phase 4: Performance Baseline**
```bash
./scripts/verify_phase.sh "Phase 4: Performance Baseline"
# Verifies 30 FPS target is met
```

**After Phase 6: Bug Fixes**
```bash
./scripts/verify_phase.sh "Phase 6: Bug Fixes & Stability"
# Confirms memory leak is fixed
```

**After Phase 8: Final Optimization**
```bash
./scripts/verify_phase.sh "Phase 8: Final Optimization"
# Validates all performance targets
```

## Performance Targets

### Element Detection
- **Target:** ≥ 30 FPS
- **Minimum:** ≥ 25 FPS

### Memory
- **Baseline:** < 200 MB
- **Peak:** < 500 MB
- **Leaks:** 0

### CPU
- **Average:** < 50%
- **Peak:** < 80%

### Startup
- **Target:** < 1 second
- **Acceptable:** < 3 seconds

## Output Format

All scripts use colored output:
- 🟢 Green: Success
- 🔴 Red: Critical failure
- 🟡 Yellow: Warning
- 🔵 Blue: Information

### Example Output

```
╔════════════════════════════════════════════════════════════╗
║           IRIS Phase Verification System v1.0            ║
╚════════════════════════════════════════════════════════════╝

Phase:     Phase 2: Module Structure
Date:      2025-01-17 10:30:45
Mode:      Full

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running: Build Verification
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Build succeeded
✓ All modules compiled
✓ No import conflicts

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running: Smoke Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ App launched successfully
✓ No crashes on startup

...

╔════════════════════════════════════════════════════════════╗
║                   Verification Summary                     ║
╚════════════════════════════════════════════════════════════╝

Phase:        Phase 2: Module Structure
Duration:     45s

Results:
  ✓ Passed:   4
  ✗ Failed:   0
  ⊘ Skipped:  0
  ━ Total:    4

╔════════════════════════════════════════════════════════════╗
║                  ✅ ALL CHECKS PASSED                      ║
╚════════════════════════════════════════════════════════════╝
```

## Temporary Files

Scripts create temporary log files in `/tmp/`:
- `iris_smoke_test_*.log` - Smoke test output
- `iris_perf_test_*.log` - Performance logs
- `iris_leak_test_*.log` - Memory leak detection
- `iris_mem_growth_*.log` - Memory growth analysis

These are automatically cleaned up after each run.

## Integration

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
./scripts/verify_phase.sh "Pre-commit Check" false true
exit $?
```

Then:
```bash
chmod +x .git/hooks/pre-commit
```

### GitHub Actions

```yaml
name: Phase Verification

on: [push, pull_request]

jobs:
  verify:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Verification
        run: ./scripts/verify_phase.sh "CI Build"
```

### VS Code Task

Add to `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Verify Phase",
      "type": "shell",
      "command": "./scripts/verify_phase.sh",
      "args": ["Current Work", "false", "true"],
      "group": {
        "kind": "test",
        "isDefault": true
      }
    }
  ]
}
```

## Troubleshooting

### Build verification fails
1. Check the error output
2. Run: `swift package clean && swift build -c release`
3. Review compilation errors

### Smoke test fails
1. Check: `/tmp/iris_smoke_test_*.log`
2. Run manually: `.build/release/IRIS`
3. Verify permissions

### Performance issues
1. Run: `./scripts/performance_check.sh`
2. Profile: `instruments -t "Time Profiler" .build/release/IRIS`
3. Check activity monitor

### Memory leaks
1. Run: `./scripts/memory_check.sh`
2. Use: `leaks $(pgrep IRIS)`
3. Profile: `instruments -t Leaks .build/release/IRIS`

### Script permissions
If you get "Permission denied":
```bash
chmod +x scripts/*.sh
```

## Documentation

For detailed information, see:
- `VERIFICATION_GUIDE.md` - Complete usage guide
- `../PHASE_CHECKLIST.md` - Phase completion checklist
- `../README.md` - Project overview

## Requirements

- macOS 14+
- Swift 5.9+
- Xcode Command Line Tools (for `leaks` and `instruments`)

## Support

For issues or questions:
1. Review this README
2. Check `VERIFICATION_GUIDE.md`
3. Review script source code
4. Check IRIS project documentation

## Version

**Version:** 1.0
**Created:** 2025-01-17
**Compatible with:** IRIS Phase 2+
