# IRIS Verification - Quick Reference Card

## 🚀 Most Common Commands

```bash
# After completing any phase
./scripts/verify_phase.sh "Phase X: Description"

# Quick check during development
./scripts/build_verify.sh

# Quick verification (30 seconds)
./scripts/verify_phase.sh "Current Work" false true
```

## 📋 Individual Checks

```bash
./scripts/build_verify.sh        # Build only (~1 min)
./scripts/smoke_test.sh          # App launch test
./scripts/performance_check.sh   # Performance metrics
./scripts/memory_check.sh        # Memory leak detection
```

## ✅ Critical Checkpoints

| Phase | Command | Focus |
|-------|---------|-------|
| **Phase 2** | `./scripts/verify_phase.sh "Phase 2"` | Module structure |
| **Phase 4** | `./scripts/verify_phase.sh "Phase 4"` | **30 FPS target** ⚡ |
| **Phase 6** | `./scripts/verify_phase.sh "Phase 6"` | **Memory leak fix** 🧠 |
| **Phase 8** | `./scripts/verify_phase.sh "Phase 8"` | **Production ready** 🎯 |

## 🎯 Performance Targets

| Metric | Target | Acceptable |
|--------|--------|------------|
| **Element Detection FPS** | ≥ 30 | ≥ 25 |
| **Memory Usage** | < 200 MB | < 500 MB |
| **CPU Average** | < 50% | < 80% |
| **Startup Time** | < 1s | < 3s |
| **Memory Leaks** | 0 | 0 |

## 🔧 Troubleshooting

### Build fails
```bash
swift package clean && swift build -c release
```

### Smoke test fails
```bash
tail -20 /tmp/iris_smoke_test_*.log
.build/release/IRIS  # Run manually
```

### Performance issues
```bash
instruments -t "Time Profiler" .build/release/IRIS
```

### Memory leaks
```bash
leaks $(pgrep IRIS)
instruments -t Leaks .build/release/IRIS
```

## 📖 Documentation

- `scripts/README.md` - Complete reference
- `scripts/VERIFICATION_GUIDE.md` - Detailed guide
- `PHASE_CHECKLIST.md` - Phase checklist
- `CONTINUOUS_BUILD_SUMMARY.md` - Implementation summary

## 🔄 Workflow

```
1. Make changes
2. Quick check:  ./scripts/build_verify.sh
3. Before commit: ./scripts/verify_phase.sh "Work" false true
4. Before PR:     ./scripts/verify_phase.sh "PR: Feature"
```

## 📊 Understanding Output

| Symbol | Meaning |
|--------|---------|
| 🟢 ✓ | Test passed |
| 🔴 ✗ | Test failed |
| 🟡 ⚠ | Warning |
| 🔵 ━ | Information |
| ⊘ | Skipped |

## ⚙️ Script Modes

### Full Mode (recommended before commits)
```bash
./scripts/verify_phase.sh "Phase Name"
# Duration: ~2-3 minutes
# Runs: Build + Smoke + Performance + Memory
```

### Quick Mode (during development)
```bash
./scripts/verify_phase.sh "Phase Name" false true
# Duration: ~30 seconds
# Runs: Build + Smoke only
```

### Build Only (fastest)
```bash
./scripts/build_verify.sh
# Duration: ~1 minute
# Runs: Build verification only
```

## 🎓 Best Practices

1. ✅ Run verification after each phase
2. ✅ Use quick mode during active development
3. ✅ Use full mode before commits/PRs
4. ✅ Fix failures immediately
5. ✅ Track performance trends
6. ❌ Don't skip critical checkpoints
7. ❌ Don't ignore warnings

## 🔗 Quick Links

| What | Where |
|------|-------|
| All scripts | `scripts/` directory |
| Usage guide | `scripts/VERIFICATION_GUIDE.md` |
| Phase checklist | `PHASE_CHECKLIST.md` |
| Full summary | `CONTINUOUS_BUILD_SUMMARY.md` |

---

**Keep this reference handy!** Pin it in your editor or print it out.
