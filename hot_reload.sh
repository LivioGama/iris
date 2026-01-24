#!/bin/bash

# IRIS Hot Reload Script
# Watches for Swift file changes and automatically rebuilds + runs

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔥 IRIS Hot Reload${NC}"
echo -e "${YELLOW}Watching for Swift file changes...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Debounce: track last build time to avoid multiple rapid builds
LAST_BUILD=0
DEBOUNCE_SECONDS=2

rebuild_and_run() {
    local CURRENT_TIME=$(date +%s)
    local TIME_DIFF=$((CURRENT_TIME - LAST_BUILD))

    # Debounce - skip if built within last N seconds
    if [ $TIME_DIFF -lt $DEBOUNCE_SECONDS ]; then
        return
    fi

    LAST_BUILD=$CURRENT_TIME

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
}

# Export function for use in subshell
export -f rebuild_and_run
export LAST_BUILD
export DEBOUNCE_SECONDS
export RED GREEN YELLOW BLUE NC

# Watch Swift files in IRIS directory and subdirectories
# Exclude build artifacts and derived data
fswatch -o \
    --exclude '\.build' \
    --exclude 'DerivedData' \
    --exclude '\.git' \
    --exclude 'libs' \
    --include '\.swift$' \
    "$PROJECT_DIR/IRIS" \
    "$PROJECT_DIR/IRISCore" \
    "$PROJECT_DIR/IRISNetwork" \
    "$PROJECT_DIR/IRISVision" \
    "$PROJECT_DIR/IRISMedia" \
    "$PROJECT_DIR/IRISGaze" \
    | while read -r event; do
        rebuild_and_run
    done
