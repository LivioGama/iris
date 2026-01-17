#!/bin/bash

# IRIS API Key Setup Script
# This script securely stores your Gemini API key in the macOS Keychain

set -e

KEYCHAIN_SERVICE="com.iris.gemini"
KEYCHAIN_ACCOUNT="gemini-api-key"

echo "==================================="
echo "IRIS Gemini API Key Setup"
echo "==================================="
echo ""

# Check if API key already exists in Keychain
if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" &>/dev/null; then
    echo "⚠️  An API key already exists in the Keychain."
    read -p "Do you want to replace it? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    # Delete existing key
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" &>/dev/null || true
    echo "✓ Removed old API key"
fi

# Prompt for API key
echo ""
echo "Please enter your Gemini API key:"
echo "(You can get one from: https://makersuite.google.com/app/apikey)"
echo ""
read -s -p "API Key: " API_KEY
echo ""

# Validate input
if [ -z "$API_KEY" ]; then
    echo "❌ Error: API key cannot be empty"
    exit 1
fi

# Store in Keychain
security add-generic-password \
    -s "$KEYCHAIN_SERVICE" \
    -a "$KEYCHAIN_ACCOUNT" \
    -w "$API_KEY" \
    -T "" \
    -U

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ API key successfully stored in Keychain!"
    echo ""
    echo "The API key is now securely stored and will be used by IRIS."
    echo "You can now run IRIS using: ./run_iris.sh"
    echo ""

    # Check if GEMINI_API_KEY is in run_iris.sh and warn
    if grep -q "export GEMINI_API_KEY=" run_iris.sh 2>/dev/null; then
        echo "⚠️  Note: run_iris.sh still contains GEMINI_API_KEY export."
        echo "   The Keychain value will take precedence."
        echo "   Consider removing the hardcoded value for security."
    fi
else
    echo ""
    echo "❌ Failed to store API key in Keychain"
    exit 1
fi
