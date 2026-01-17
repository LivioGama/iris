#!/bin/bash

# Security Verification Script for IRIS
# This script verifies that no API keys are exposed in the codebase

set -e

echo "==================================="
echo "IRIS Security Verification"
echo "==================================="
echo ""

FAILED=0

# Check 1: No hardcoded API keys in source files
echo "[1/4] Checking for hardcoded API keys..."
if grep -r "AIzaSy" . --exclude-dir=.git --exclude-dir=.build --exclude-dir=scripts --exclude-dir=gaze_env 2>/dev/null; then
    echo "❌ FAIL: Found hardcoded API keys in source code"
    FAILED=1
else
    echo "✅ PASS: No hardcoded API keys found"
fi

# Check 2: Verify KeychainService exists
echo ""
echo "[2/4] Checking KeychainService implementation..."
if [ -f "IRIS/Services/KeychainService.swift" ]; then
    echo "✅ PASS: KeychainService.swift exists"
else
    echo "❌ FAIL: KeychainService.swift not found"
    FAILED=1
fi

# Check 3: Verify services use KeychainService
echo ""
echo "[3/4] Checking service integration..."
if grep -q "KeychainService" IRIS/Services/GeminiAssistantService.swift && \
   grep -q "KeychainService" IRIS/Services/SentimentAnalysisService.swift; then
    echo "✅ PASS: Services integrated with KeychainService"
else
    echo "❌ FAIL: Services not properly integrated"
    FAILED=1
fi

# Check 4: Verify setup script exists and is executable
echo ""
echo "[4/4] Checking setup script..."
if [ -x "scripts/setup_api_key.sh" ]; then
    echo "✅ PASS: Setup script exists and is executable"
else
    echo "❌ FAIL: Setup script missing or not executable"
    FAILED=1
fi

echo ""
echo "==================================="
if [ $FAILED -eq 0 ]; then
    echo "✅ ALL CHECKS PASSED"
    echo "Security hardening complete!"
    echo ""
    echo "Next steps:"
    echo "1. Run: ./scripts/setup_api_key.sh"
    echo "2. Test: ./run_iris.sh"
else
    echo "❌ SOME CHECKS FAILED"
    echo "Please review the failures above"
    exit 1
fi
echo "==================================="
