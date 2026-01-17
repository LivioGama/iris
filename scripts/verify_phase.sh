#!/bin/bash

# Master Phase Verification Script
# Runs all verification steps after each development phase

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Parse command line arguments
PHASE_NAME="${1:-Unknown Phase}"
SKIP_BUILD="${2:-false}"
QUICK_MODE="${3:-false}"

# Display header
clear
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║           IRIS Phase Verification System v1.0            ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Phase:${NC} $PHASE_NAME"
echo -e "${BOLD}Date:${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BOLD}Mode:${NC}  $([ "$QUICK_MODE" = "true" ] && echo "Quick" || echo "Full")"
echo ""

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
SKIPPED_CHECKS=0

# Function to run a verification step
run_check() {
    local check_name="$1"
    local script_path="$2"
    local required="$3"  # true if failure should stop entire verification

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Running: $check_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ ! -f "$script_path" ]; then
        echo -e "${RED}✗ Script not found: $script_path${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        if [ "$required" = "true" ]; then
            exit 1
        fi
        return 1
    fi

    # Make script executable
    chmod +x "$script_path"

    # Run the script
    if bash "$script_path"; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo ""
        return 0
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo ""
        echo -e "${RED}✗ $check_name failed${NC}"

        if [ "$required" = "true" ]; then
            echo -e "${RED}This is a critical check. Stopping verification.${NC}"
            exit 1
        fi
        return 1
    fi
}

# Start verification
START_TIME=$(date +%s)

cd "$PROJECT_DIR"

echo -e "${BLUE}Starting verification workflow...${NC}"
echo ""

# Step 1: Build Verification (Critical)
if [ "$SKIP_BUILD" != "true" ]; then
    run_check "Build Verification" "$SCRIPT_DIR/build_verify.sh" "true"
else
    echo -e "${YELLOW}⊘ Skipping build (as requested)${NC}"
    SKIPPED_CHECKS=$((SKIPPED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo ""
fi

# Step 2: Smoke Test (Critical)
run_check "Smoke Test" "$SCRIPT_DIR/smoke_test.sh" "true"

# Step 3: Performance Check (Warning only in quick mode)
if [ "$QUICK_MODE" != "true" ]; then
    run_check "Performance Check" "$SCRIPT_DIR/performance_check.sh" "false"
else
    echo -e "${YELLOW}⊘ Skipping performance check (quick mode)${NC}"
    SKIPPED_CHECKS=$((SKIPPED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo ""
fi

# Step 4: Memory Check (Warning only in quick mode)
if [ "$QUICK_MODE" != "true" ]; then
    run_check "Memory Check" "$SCRIPT_DIR/memory_check.sh" "false"
else
    echo -e "${YELLOW}⊘ Skipping memory check (quick mode)${NC}"
    SKIPPED_CHECKS=$((SKIPPED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo ""
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Display final summary
echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                   Verification Summary                     ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Phase:${NC}        $PHASE_NAME"
echo -e "${BOLD}Duration:${NC}     ${DURATION}s"
echo ""
echo -e "${BOLD}Results:${NC}"
echo -e "  ${GREEN}✓ Passed:${NC}   $PASSED_CHECKS"
echo -e "  ${RED}✗ Failed:${NC}   $FAILED_CHECKS"
echo -e "  ${YELLOW}⊘ Skipped:${NC}  $SKIPPED_CHECKS"
echo -e "  ${BLUE}━ Total:${NC}    $TOTAL_CHECKS"
echo ""

# Determine overall status
if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║                  ✅ ALL CHECKS PASSED                      ║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Phase verification successful! You can proceed to the next phase.${NC}"
    echo ""
    exit 0
else
    echo -e "${BOLD}${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║                  ❌ VERIFICATION FAILED                     ║${NC}"
    echo -e "${BOLD}${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}Please fix the failures before proceeding to the next phase.${NC}"
    echo ""
    exit 1
fi
