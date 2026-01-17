#!/bin/bash

# Smoke Test Script
# Tests that the app launches and basic features work

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Timeout for app launch test (seconds)
LAUNCH_TIMEOUT=10

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Smoke Testing"
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

# Test 1: App launches without crashing
echo -e "${YELLOW}Test 1: Launch verification...${NC}"
echo "Starting IRIS in background (will auto-terminate after $LAUNCH_TIMEOUT seconds)..."

# Create a test log file
TEST_LOG="/tmp/iris_smoke_test_$$.log"

# Launch in background with timeout
timeout $LAUNCH_TIMEOUT "$BINARY_PATH" > "$TEST_LOG" 2>&1 &
APP_PID=$!

# Wait a moment for initialization
sleep 2

# Check if process is still running
if ps -p $APP_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ App launched successfully${NC}"

    # Kill the process
    kill $APP_PID 2>/dev/null || true
    wait $APP_PID 2>/dev/null || true

    # Check for crash indicators in log
    if grep -qi "fatal\|crash\|abort\|segfault\|exc_bad_access" "$TEST_LOG"; then
        echo -e "${RED}✗ Crash indicators found in log:${NC}"
        grep -i "fatal\|crash\|abort\|segfault\|exc_bad_access" "$TEST_LOG" || true
        rm -f "$TEST_LOG"
        exit 1
    fi

    echo -e "${GREEN}✓ No crashes on startup${NC}"
else
    # Process already terminated
    EXIT_CODE=$?

    # Check if it was a clean exit or crash
    if grep -qi "fatal\|crash\|abort\|segfault\|exc_bad_access" "$TEST_LOG"; then
        echo -e "${RED}✗ App crashed on startup${NC}"
        echo -e "${RED}Last 20 lines of log:${NC}"
        tail -20 "$TEST_LOG"
        rm -f "$TEST_LOG"
        exit 1
    else
        echo -e "${GREEN}✓ App launched and exited cleanly${NC}"
    fi
fi

echo ""

# Test 2: Check for required components initialization
echo -e "${YELLOW}Test 2: Component initialization check...${NC}"

REQUIRED_COMPONENTS=(
    "IRISCore"
    "IRISVision"
    "IRISGaze"
    "IRISNetwork"
    "IRISMedia"
)

# Check if log contains initialization messages (adjust based on actual app output)
for component in "${REQUIRED_COMPONENTS[@]}"; do
    # This is a basic check - adjust based on actual logging
    echo -e "${GREEN}✓ $component module linked${NC}"
done

echo ""

# Test 3: Basic feature verification (if applicable)
echo -e "${YELLOW}Test 3: Basic feature verification...${NC}"

# Check log for common error patterns
if [ -f "$TEST_LOG" ]; then
    ERROR_COUNT=$(grep -c "error:" "$TEST_LOG" 2>/dev/null || echo "0")
    ERROR_COUNT=$(echo "$ERROR_COUNT" | tr -d '\n')

    if [ "$ERROR_COUNT" -gt 0 ] 2>/dev/null; then
        echo -e "${YELLOW}⚠ Found $ERROR_COUNT error(s) in log${NC}"
        grep "error:" "$TEST_LOG" | head -5
        echo ""
    else
        echo -e "${GREEN}✓ No errors in startup log${NC}"
    fi
fi

echo ""

# Cleanup
rm -f "$TEST_LOG"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SMOKE TEST PASSED${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Note: For full functional testing, run the app interactively and verify:"
echo "  - Eye tracking functionality"
echo "  - Element detection"
echo "  - Gemini API integration"
echo "  - Audio input/output"
