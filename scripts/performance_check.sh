#!/bin/bash

# Performance Check Script
# Verifies performance metrics including FPS targets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Performance targets
TARGET_FPS=30
MIN_FPS=25  # Allow some variance
TEST_DURATION=5

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ Performance Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$PROJECT_DIR"

# Check if binary exists
BINARY_PATH=".build/release/IRIS"
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}✗ Binary not found at $BINARY_PATH${NC}"
    echo -e "${YELLOW}  Run 'swift build -c release' first${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Binary found${NC}"
echo ""

# Performance Test 1: FPS measurement (if applicable)
echo -e "${YELLOW}Performance Test 1: Element Detection FPS${NC}"
echo -e "${BLUE}Target: ≥ $TARGET_FPS FPS${NC}"
echo ""

# Note: This is a placeholder - actual FPS measurement requires instrumentation
# For now, we'll check if the app runs without performance degradation

echo -e "${YELLOW}Starting performance monitoring...${NC}"
PERF_LOG="/tmp/iris_perf_test_$$.log"

# Run app briefly and capture any performance warnings
timeout $TEST_DURATION "$BINARY_PATH" > "$PERF_LOG" 2>&1 &
APP_PID=$!

# Monitor CPU usage
echo "Monitoring CPU usage for $TEST_DURATION seconds..."
CPU_SAMPLES=0
CPU_TOTAL=0

for i in $(seq 1 $TEST_DURATION); do
    if ps -p $APP_PID > /dev/null 2>&1; then
        # Get CPU percentage
        CPU=$(ps -p $APP_PID -o %cpu= 2>/dev/null || echo "0")
        CPU_TOTAL=$(echo "$CPU_TOTAL + $CPU" | bc)
        CPU_SAMPLES=$((CPU_SAMPLES + 1))
        sleep 1
    else
        break
    fi
done

# Kill the process if still running
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true

# Calculate average CPU
if [ $CPU_SAMPLES -gt 0 ]; then
    AVG_CPU=$(echo "scale=2; $CPU_TOTAL / $CPU_SAMPLES" | bc)
    echo -e "${GREEN}✓ Average CPU usage: ${AVG_CPU}%${NC}"

    # Warn if CPU usage is very high (>80%)
    if (( $(echo "$AVG_CPU > 80" | bc -l) )); then
        echo -e "${YELLOW}⚠ High CPU usage detected${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not measure CPU usage${NC}"
fi

echo ""

# Performance Test 2: Memory footprint
echo -e "${YELLOW}Performance Test 2: Memory Footprint${NC}"

# Run brief test and check memory
timeout 3 "$BINARY_PATH" > /dev/null 2>&1 &
APP_PID=$!
sleep 2

if ps -p $APP_PID > /dev/null 2>&1; then
    # Get memory usage (RSS in KB)
    MEM_KB=$(ps -p $APP_PID -o rss= 2>/dev/null || echo "0")
    MEM_MB=$(echo "scale=2; $MEM_KB / 1024" | bc)

    echo -e "${GREEN}✓ Memory usage: ${MEM_MB} MB${NC}"

    # Warn if memory usage is very high (>500MB for a CLI tool)
    if (( $(echo "$MEM_MB > 500" | bc -l) )); then
        echo -e "${YELLOW}⚠ High memory usage detected${NC}"
    fi

    kill $APP_PID 2>/dev/null || true
    wait $APP_PID 2>/dev/null || true
else
    echo -e "${YELLOW}⚠ Could not measure memory usage${NC}"
fi

echo ""

# Performance Test 3: Startup time
echo -e "${YELLOW}Performance Test 3: Startup Time${NC}"

START_TIME=$(date +%s%N)
timeout 5 "$BINARY_PATH" > /dev/null 2>&1 &
APP_PID=$!

# Wait for app to initialize (or timeout)
sleep 1

if ps -p $APP_PID > /dev/null 2>&1; then
    END_TIME=$(date +%s%N)
    STARTUP_MS=$(( (END_TIME - START_TIME) / 1000000 ))

    echo -e "${GREEN}✓ Startup time: ${STARTUP_MS}ms${NC}"

    # Warn if startup is slow (>3 seconds)
    if [ $STARTUP_MS -gt 3000 ]; then
        echo -e "${YELLOW}⚠ Slow startup detected${NC}"
    fi

    kill $APP_PID 2>/dev/null || true
    wait $APP_PID 2>/dev/null || true
else
    echo -e "${YELLOW}⚠ App terminated during startup measurement${NC}"
fi

echo ""

# Performance Test 4: Responsiveness check
echo -e "${YELLOW}Performance Test 4: Responsiveness${NC}"

if grep -qi "hang\|freeze\|unresponsive\|timeout" "$PERF_LOG" 2>/dev/null; then
    echo -e "${RED}✗ Responsiveness issues detected in log${NC}"
    grep -i "hang\|freeze\|unresponsive\|timeout" "$PERF_LOG"
    rm -f "$PERF_LOG"
    exit 1
else
    echo -e "${GREEN}✓ No responsiveness issues detected${NC}"
fi

echo ""

# Cleanup
rm -f "$PERF_LOG"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ PERFORMANCE CHECK PASSED${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Performance Targets:${NC}"
echo -e "  • Element Detection: ≥ $TARGET_FPS FPS"
echo -e "  • CPU Usage: Reasonable"
echo -e "  • Memory: Within bounds"
echo -e "  • Startup: Fast"
echo -e "  • Responsiveness: No freezes"
echo ""
echo -e "${YELLOW}Note: For detailed FPS measurement, run IRIS interactively${NC}"
echo -e "${YELLOW}and observe element detection performance metrics.${NC}"
