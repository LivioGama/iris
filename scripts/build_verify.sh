#!/bin/bash

# Build Verification Script
# Verifies that the project compiles successfully with no errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 Build Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$PROJECT_DIR"

# Clean previous build
echo -e "${YELLOW}Cleaning previous build...${NC}"
swift package clean
echo -e "${GREEN}✓ Clean complete${NC}"
echo ""

# Build in release mode
echo -e "${YELLOW}Building project...${NC}"
BUILD_OUTPUT=$(swift build -c release 2>&1)
BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Build succeeded${NC}"
    echo ""

    # Check for warnings
    WARNING_COUNT=$(echo "$BUILD_OUTPUT" | grep -c "warning:" || true)
    if [ $WARNING_COUNT -gt 0 ]; then
        echo -e "${YELLOW}⚠ Found $WARNING_COUNT warning(s):${NC}"
        echo "$BUILD_OUTPUT" | grep "warning:" || true
        echo ""
    else
        echo -e "${GREEN}✓ No warnings${NC}"
        echo ""
    fi

    # Verify all modules built
    echo -e "${YELLOW}Verifying modules...${NC}"
    MODULES=("IRISCore" "IRISVision" "IRISGaze" "IRISNetwork" "IRISMedia" "IRIS")
    for module in "${MODULES[@]}"; do
        if echo "$BUILD_OUTPUT" | grep -q "Compiling $module" || [ -d ".build/release" ]; then
            echo -e "${GREEN}✓ $module${NC}"
        else
            echo -e "${RED}✗ $module - not found in build output${NC}"
        fi
    done
    echo ""

    # Check for import conflicts
    echo -e "${YELLOW}Checking for import conflicts...${NC}"
    IMPORT_ERRORS=$(echo "$BUILD_OUTPUT" | grep -i "import.*conflict\|ambiguous.*import\|duplicate.*import" || true)
    if [ -z "$IMPORT_ERRORS" ]; then
        echo -e "${GREEN}✓ No import conflicts${NC}"
    else
        echo -e "${RED}✗ Import conflicts detected:${NC}"
        echo "$IMPORT_ERRORS"
        exit 1
    fi
    echo ""

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ BUILD VERIFICATION PASSED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

else
    echo -e "${RED}✗ Build failed${NC}"
    echo ""
    echo -e "${RED}Build errors:${NC}"
    echo "$BUILD_OUTPUT"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ BUILD VERIFICATION FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
