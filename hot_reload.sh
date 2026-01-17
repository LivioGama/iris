#!/bin/bash

# IRIS Hot Reload Script
# Watches for Swift file changes and automatically rebuilds + runs

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# State file for debouncing
LAST_BUILD_FILE="/tmp/iris_hot_reload_last_build"
DEBOUNCE_SECONDS=5

echo -e "${BLUE}🔥 IRIS Hot Reload${NC}"
echo -e "${YELLOW}Watching for Swift file changes...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Cleanup on exit
cleanup() {
    rm -f "$LAST_BUILD_FILE"
    echo -e "\n${YELLOW}Hot reload stopped${NC}"
    exit 0
}
trap cleanup EXIT INT TERM

# Initialize last build time
echo "0" > "$LAST_BUILD_FILE"

echo -e "${YELLOW}👀 Watching for changes...${NC}"

# Watch only Swift source files, with heavy filtering
fswatch --one-per-batch \
    --latency=2 \
    --recursive \
    --include='\.swift$' \
    --exclude='.*' \
    "$PROJECT_DIR/IRIS" \
    "$PROJECT_DIR/IRISCore/Sources" \
    "$PROJECT_DIR/IRISNetwork/Sources" \
    "$PROJECT_DIR/IRISVision/Sources" \
    "$PROJECT_DIR/IRISMedia/Sources" \
    "$PROJECT_DIR/IRISGaze/Sources" \
    | while read -r changed_files; do
        # Debounce check
        LAST_BUILD=$(cat "$LAST_BUILD_FILE" 2>/dev/null || echo "0")
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - LAST_BUILD))

        if [ $TIME_DIFF -lt $DEBOUNCE_SECONDS ]; then
            echo -e "${YELLOW}⏳ Skipping (debounce)${NC}"
            continue
        fi

        # Update last build time
        echo "$CURRENT_TIME" > "$LAST_BUILD_FILE"

        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}🔄 Change detected, rebuilding...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Run the build script
        if ./build_and_install.sh; then
            echo -e "${GREEN}✅ Build succeeded, app relaunched${NC}"
        else
            echo -e "${RED}❌ Build failed${NC}"
        fi

        echo ""
        echo -e "${YELLOW}👀 Watching for changes...${NC}"
    done
