# IRIS Phase Verification Guide

Continuous build and testing verification system for IRIS development phases.

## Quick Start

### After Completing a Phase

```bash
# Run full verification
./scripts/verify_phase.sh "Phase X: Description"

# Quick verification (skip performance/memory checks)
./scripts/verify_phase.sh "Phase X: Description" false true

# Skip build and run quick verification
./scripts/verify_phase.sh "Phase X: Description" true true
```

## Individual Checks

Run specific verification steps independently:

### 1. Build Verification

```bash
./scripts/build_verify.sh
```

**What it checks:**
- ✓ Project compiles successfully
- ✓ No compilation errors
- ✓ No import conflicts
- ✓ All modules build correctly

**Critical:** Build must pass before other tests.

### 2. Smoke Test

```bash
./scripts/smoke_test.sh
```

**What it checks:**
- ✓ App launches successfully
- ✓ No crashes on startup
- ✓ Basic features initialize
- ✓ All modules load correctly

**Critical:** Must pass for phase completion.

### 3. Performance Check

```bash
./scripts/performance_check.sh
```

**What it checks:**
- ✓ CPU usage is reasonable
- ✓ Memory footprint within bounds
- ✓ Fast startup time
- ✓ No responsiveness issues
- ✓ 30 FPS element detection target

**Warning only:** Failures are logged but don't block.

### 4. Memory Check

```bash
./scripts/memory_check.sh
```

**What it checks:**
- ✓ No memory leaks
- ✓ Memory growth within limits
- ✓ Conversation history bounded
- ✓ No excessive allocations

**Warning only:** Failures are logged but don't block.

## Phase-Specific Checkpoints

### Critical Checkpoints

#### After Phase 2: Module Structure
```bash
./scripts/verify_phase.sh "Phase 2: Module Structure" false false
```
**Focus:** Verify all modules build and link correctly.

#### After Phase 4: Performance Baseline
```bash
./scripts/verify_phase.sh "Phase 4: Performance Baseline" false false
```
**Focus:** Ensure 30 FPS maintained for element detection.

#### After Phase 6: Memory Leak Fix
```bash
./scripts/verify_phase.sh "Phase 6: Memory Leak Fix" false false
```
**Focus:** Verify memory leak is fixed and all features work.

#### After Phase 8: Final Performance
```bash
./scripts/verify_phase.sh "Phase 8: Final Performance" false false
```
**Focus:** Confirm all performance targets are met.

## Verification Modes

### Full Verification (Recommended)
```bash
./scripts/verify_phase.sh "Phase Name"
```
- Runs all checks
- Takes ~2-3 minutes
- Use for phase completion

### Quick Verification
```bash
./scripts/verify_phase.sh "Phase Name" false true
```
- Skips performance and memory checks
- Takes ~30 seconds
- Use for rapid iteration

### Build-Only Verification
```bash
./scripts/build_verify.sh
```
- Only verifies compilation
- Takes ~1 minute
- Use during active development

## Performance Targets

### Element Detection
- **Target:** ≥ 30 FPS
- **Minimum:** ≥ 25 FPS
- **Measurement:** Real-time element detection

### Memory Usage
- **Baseline:** < 200 MB
- **Peak:** < 500 MB
- **Leaks:** 0

### Startup Time
- **Target:** < 1 second
- **Acceptable:** < 3 seconds

### CPU Usage
- **Target:** < 50% average
- **Peak:** < 80%

## Troubleshooting

### Build Verification Fails

1. Check compilation errors:
   ```bash
   swift build -c release 2>&1 | grep "error:"
   ```

2. Clean and rebuild:
   ```bash
   swift package clean
   swift build -c release
   ```

3. Check for import conflicts:
   ```bash
   grep -r "import" */Sources/ | sort | uniq -c
   ```

### Smoke Test Fails

1. Check crash logs:
   ```bash
   tail -20 /tmp/iris_smoke_test_*.log
   ```

2. Run app manually to see errors:
   ```bash
   .build/release/IRIS
   ```

3. Check for missing dependencies:
   ```bash
   swift package show-dependencies
   ```

### Performance Issues

1. Profile with Instruments:
   ```bash
   instruments -t "Time Profiler" -D /tmp/profile.trace .build/release/IRIS
   ```

2. Check CPU usage:
   ```bash
   top -pid $(pgrep IRIS)
   ```

3. Monitor real-time performance:
   ```bash
   ./scripts/performance_check.sh
   ```

### Memory Leaks

1. Use leaks command:
   ```bash
   leaks $(pgrep IRIS)
   ```

2. Profile with Instruments:
   ```bash
   instruments -t Leaks -D /tmp/leaks.trace .build/release/IRIS
   ```

3. Check allocations:
   ```bash
   instruments -t Allocations -D /tmp/allocs.trace .build/release/IRIS
   ```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Phase Verification

on: [push, pull_request]

jobs:
  verify:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Phase Verification
        run: ./scripts/verify_phase.sh "CI Build" false false
```

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
./scripts/build_verify.sh
exit $?
```

## Best Practices

1. **Always verify after each phase** - Catch issues early
2. **Run full verification before commits** - Ensure quality
3. **Use quick mode during development** - Fast feedback
4. **Monitor performance trends** - Track degradation
5. **Fix failures immediately** - Don't accumulate tech debt

## Script Outputs

All scripts generate colored output:
- 🟢 **Green:** Tests passed
- 🔴 **Red:** Critical failures
- 🟡 **Yellow:** Warnings
- 🔵 **Blue:** Information

### Log Files

Temporary logs are created in `/tmp/`:
- `iris_smoke_test_*.log` - Smoke test output
- `iris_perf_test_*.log` - Performance logs
- `iris_leak_test_*.log` - Memory leak detection
- `iris_mem_growth_*.log` - Memory growth analysis

Logs are automatically cleaned up after each run.

## Support

For issues or questions:
1. Check this guide first
2. Review script source code in `scripts/`
3. Check IRIS documentation
4. Report bugs with verification output attached
