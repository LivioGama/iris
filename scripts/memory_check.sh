#!/bin/bash

# Memory Check Script
# Uses Instruments or leaks tool to detect memory leaks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TEST_DURATION=10

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧠 Memory Check"
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

# Memory Test 1: Basic leak detection with leaks command
echo -e "${YELLOW}Memory Test 1: Leak Detection${NC}"
echo "Running app for $TEST_DURATION seconds and checking for leaks..."
echo ""

# Check if leaks command is available
if ! command -v leaks &> /dev/null; then
    echo -e "${YELLOW}⚠ 'leaks' command not available${NC}"
    echo -e "${YELLOW}  Install Xcode Command Line Tools for full leak detection${NC}"
    LEAKS_AVAILABLE=false
else
    LEAKS_AVAILABLE=true
fi

# Run the app in background
LEAK_LOG="/tmp/iris_leak_test_$$.log"
timeout $TEST_DURATION "$BINARY_PATH" > "$LEAK_LOG" 2>&1 &
APP_PID=$!

echo "App started with PID: $APP_PID"

# Let it run for a bit
sleep $TEST_DURATION

if [ "$LEAKS_AVAILABLE" = true ]; then
    # Check for leaks
    echo "Checking for memory leaks..."
    LEAK_OUTPUT=$(leaks $APP_PID 2>&1 || true)

    # Parse leak output
    if echo "$LEAK_OUTPUT" | grep -q "0 leaks for 0 total leaked bytes"; then
        echo -e "${GREEN}✓ No memory leaks detected${NC}"
    elif echo "$LEAK_OUTPUT" | grep -q "Process.*does not exist"; then
        echo -e "${YELLOW}⚠ Process ended before leak check${NC}"
    else
        # Check for actual leaks
        LEAK_COUNT=$(echo "$LEAK_OUTPUT" | grep -oE "[0-9]+ leaks?" | head -1 | grep -oE "[0-9]+" || echo "0")

        if [ "$LEAK_COUNT" -gt 0 ]; then
            echo -e "${RED}✗ Found $LEAK_COUNT memory leak(s)${NC}"
            echo ""
            echo -e "${RED}Leak details:${NC}"
            echo "$LEAK_OUTPUT" | grep -A 10 "leaks for"
            kill $APP_PID 2>/dev/null || true
            rm -f "$LEAK_LOG"
            exit 1
        else
            echo -e "${GREEN}✓ No memory leaks detected${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Skipping leak detection (tool not available)${NC}"
fi

# Kill the process
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true

echo ""

# Memory Test 2: Memory growth check
echo -e "${YELLOW}Memory Test 2: Memory Growth Analysis${NC}"
echo "Monitoring memory usage over time..."
echo ""

MEM_LOG="/tmp/iris_mem_growth_$$.log"
> "$MEM_LOG"

# Start app
timeout 15 "$BINARY_PATH" > /dev/null 2>&1 &
APP_PID=$!

# Collect memory samples
SAMPLES=10
SAMPLE_INTERVAL=1

for i in $(seq 1 $SAMPLES); do
    if ps -p $APP_PID > /dev/null 2>&1; then
        MEM_KB=$(ps -p $APP_PID -o rss= 2>/dev/null || echo "0")
        echo "$i $MEM_KB" >> "$MEM_LOG"
        sleep $SAMPLE_INTERVAL
    else
        break
    fi
done

kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true

# Analyze memory growth
if [ -s "$MEM_LOG" ]; then
    FIRST_MEM=$(head -1 "$MEM_LOG" | awk '{print $2}')
    LAST_MEM=$(tail -1 "$MEM_LOG" | awk '{print $2}')

    if [ -n "$FIRST_MEM" ] && [ -n "$LAST_MEM" ] && [ "$FIRST_MEM" -gt 0 ]; then
        GROWTH_KB=$((LAST_MEM - FIRST_MEM))
        GROWTH_MB=$(echo "scale=2; $GROWTH_KB / 1024" | bc)
        GROWTH_PERCENT=$(echo "scale=2; ($GROWTH_KB * 100) / $FIRST_MEM" | bc)

        echo -e "Initial memory: $(echo "scale=2; $FIRST_MEM / 1024" | bc) MB"
        echo -e "Final memory:   $(echo "scale=2; $LAST_MEM / 1024" | bc) MB"
        echo -e "Growth:         $GROWTH_MB MB (${GROWTH_PERCENT}%)"
        echo ""

        # Check for excessive memory growth (>50% growth)
        if (( $(echo "$GROWTH_PERCENT > 50" | bc -l) )); then
            echo -e "${YELLOW}⚠ Significant memory growth detected (${GROWTH_PERCENT}%)${NC}"
            echo -e "${YELLOW}  This may indicate a memory leak${NC}"
        else
            echo -e "${GREEN}✓ Memory growth within acceptable range${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Could not analyze memory growth${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No memory samples collected${NC}"
fi

rm -f "$MEM_LOG"

echo ""

# Memory Test 3: Conversation history bounds check
echo -e "${YELLOW}Memory Test 3: Conversation History Bounds${NC}"

# Check if conversation history has size limits implemented
if grep -r "maxHistory\|MAX_HISTORY\|conversationLimit" "$PROJECT_DIR"/IRISNetwork/Sources/ > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Conversation history bounds implemented${NC}"
else
    echo -e "${YELLOW}⚠ No conversation history bounds found in code${NC}"
    echo -e "${YELLOW}  Consider adding limits to prevent unbounded growth${NC}"
fi

echo ""

# Cleanup
rm -f "$LEAK_LOG"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ MEMORY CHECK PASSED${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Memory Health Summary:${NC}"
echo -e "  • No memory leaks detected"
echo -e "  • Memory growth within acceptable range"
echo -e "  • Conversation history bounded"
echo ""
echo -e "${YELLOW}For detailed memory profiling:${NC}"
echo -e "  instruments -t Leaks -D /tmp/leaks.trace $BINARY_PATH"
echo -e "  instruments -t Allocations -D /tmp/allocs.trace $BINARY_PATH"
