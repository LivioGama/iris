# IRIS Phase Completion Checklist

Use this checklist after completing each development phase to ensure quality and prevent regressions.

## Quick Reference

```bash
# Full verification (recommended)
./scripts/verify_phase.sh "Phase X: Description"

# Quick verification during development
./scripts/verify_phase.sh "Phase X: Description" false true
```

---

## Phase 1: Foundation Setup
**Status:** [ ] Not Started / [ ] In Progress / [ ] Complete

### Tasks
- [ ] Core architecture established
- [ ] Module structure defined
- [ ] Basic dependencies configured

### Verification
```bash
./scripts/verify_phase.sh "Phase 1: Foundation Setup"
```

**Critical Checks:**
- [x] Build succeeds
- [x] All modules compile
- [x] No import conflicts

---

## Phase 2: Module Structure
**Status:** [ ] Not Started / [ ] In Progress / [ ] Complete

### Tasks
- [ ] IRISCore module implemented
- [ ] IRISVision module implemented
- [ ] IRISGaze module implemented
- [ ] IRISNetwork module implemented
- [ ] IRISMedia module implemented
- [ ] Module dependencies validated

### Verification
```bash
./scripts/verify_phase.sh "Phase 2: Module Structure"
```

**Critical Checks:**
- [x] Build succeeds
- [x] All 5 modules compile independently
- [x] Dependencies resolve correctly
- [x] App launches without crashes

---

## Phase 3: Core Features
**Status:** [ ] Not Started / [ ] In Progress / [ ] Complete

### Tasks
- [ ] Eye tracking integrated
- [ ] Element detection working
- [ ] Text recognition functional
- [ ] Basic UI responsive

### Verification
```bash
./scripts/verify_phase.sh "Phase 3: Core Features"
```

**Critical Checks:**
- [x] Build succeeds
- [x] App launches
- [x] No crashes during feature usage
- [x] Basic performance acceptable

---

## Phase 4: Performance Baseline
**Status:** [ ] Not Started / [ ] In Progress / [ ] Complete

### Tasks
- [ ] Performance profiling completed
- [ ] Bottlenecks identified
- [ ] 30 FPS element detection achieved
- [ ] Optimizations implemented

### Verification
```bash
./scripts/verify_phase.sh "Phase 4: Performance Baseline"
```

**Critical Checks:**
- [x] Build succeeds
- [x] App launches
- [x] **30 FPS maintained** ⚡
- [x] CPU usage reasonable
- [x] No performance regressions

---

## Phase 5: Integration
**Status:** [ ] Not Started / [ ] In Progress / [ ] Complete

### Tasks
- [ ] Gemini API integrated
- [ ] Audio services connected
- [ ] Screenshot functionality working
- [ ] End-to-end flow functional

### Verification
```bash
./scripts/verify_phase.sh "Phase 5: Integration"
```

**Critical Checks:**
- [x] Build succeeds
- [x] All services initialize
- [x] API calls successful
- [x] No integration failures

---

## Phase 6: Bug Fixes & Stability
**Status:** [ ] Not Started / [ ] In Progress / [ ] Complete

### Tasks
- [ ] Memory leak fixed
- [ ] Known bugs resolved
- [ ] Error handling improved
- [ ] Stability tested

### Verification
```bash
./scripts/verify_phase.sh "Phase 6: Bug Fixes & Stability"
```

**Critical Checks:**
- [x] Build succeeds
- [x] App launches
- [x] **Memory leak fixed** 🧠
- [x] All features work
- [x] No crashes
- [x] Conversation history bounded

---

## Phase 7: Polish & UX
**Status:** [ ] Not Started / [ ] In Progress / [ ] Complete

### Tasks
- [ ] UI polished
- [ ] Error messages improved
- [ ] User feedback implemented
- [ ] Edge cases handled

### Verification
```bash
./scripts/verify_phase.sh "Phase 7: Polish & UX"
```

**Critical Checks:**
- [x] Build succeeds
- [x] App launches
- [x] No UX regressions
- [x] All features still work

---

## Phase 8: Final Optimization
**Status:** [ ] Not Started / [ ] In Progress / [ ] Complete

### Tasks
- [ ] Final performance tuning
- [ ] Code cleanup
- [ ] Documentation updated
- [ ] Release preparation

### Verification
```bash
./scripts/verify_phase.sh "Phase 8: Final Optimization"
```

**Critical Checks:**
- [x] Build succeeds
- [x] App launches
- [x] **All performance targets met** ⚡
- [x] No memory leaks 🧠
- [x] All features functional
- [x] Production ready

**Performance Targets:**
- Element Detection: ≥ 30 FPS
- Memory Usage: < 500 MB
- CPU Usage: < 80%
- Startup Time: < 3s
- No responsiveness issues

---

## Continuous Verification

### After Each Code Change
```bash
# Quick check during active development
./scripts/build_verify.sh
```

### Before Each Commit
```bash
# Quick verification
./scripts/verify_phase.sh "Current Work" false true
```

### Before Pull Request
```bash
# Full verification
./scripts/verify_phase.sh "PR: Feature Name"
```

### Daily/Weekly
```bash
# Full verification with all checks
./scripts/verify_phase.sh "Daily Health Check"
```

---

## Troubleshooting Quick Reference

### Build Fails
1. Check error output
2. Clean and rebuild: `swift package clean && swift build`
3. Verify dependencies: `swift package show-dependencies`

### Smoke Test Fails
1. Check logs: `tail -20 /tmp/iris_smoke_test_*.log`
2. Run manually: `.build/release/IRIS`
3. Check permissions and dependencies

### Performance Issues
1. Profile: `instruments -t "Time Profiler" .build/release/IRIS`
2. Check CPU: `top -pid $(pgrep IRIS)`
3. Monitor real-time: `./scripts/performance_check.sh`

### Memory Leaks
1. Quick check: `leaks $(pgrep IRIS)`
2. Full profile: `instruments -t Leaks .build/release/IRIS`
3. Review conversation history bounds

---

## Success Criteria

A phase is considered **complete** when:

1. ✅ All planned tasks are finished
2. ✅ Full verification passes (`./scripts/verify_phase.sh "Phase X"`)
3. ✅ No critical bugs remain
4. ✅ Performance targets met
5. ✅ Code reviewed
6. ✅ Documentation updated

---

## Notes

- **Critical phases** (2, 4, 6, 8) require extra attention
- **Always run full verification** before moving to next phase
- **Document any known issues** that are deferred
- **Track performance trends** across phases
- **Don't skip verification** to save time - it costs more to fix issues later

---

## Verification History

Keep a log of verification results:

```
Phase 1 - 2025-01-XX: ✅ PASSED (build, smoke)
Phase 2 - 2025-01-XX: ✅ PASSED (all checks)
Phase 3 - 2025-01-XX: ✅ PASSED (all checks)
Phase 4 - 2025-01-XX: ✅ PASSED (30 FPS achieved)
Phase 5 - 2025-01-XX: ✅ PASSED (all checks)
Phase 6 - 2025-01-XX: ✅ PASSED (memory leak fixed)
Phase 7 - 2025-01-XX: ✅ PASSED (all checks)
Phase 8 - 2025-01-XX: ✅ PASSED (production ready)
```
