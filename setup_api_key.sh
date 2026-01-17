#!/bin/bash

echo ""
echo "======================================================================"
echo "IRIS Setup - Gemini API Key Required"
echo "======================================================================"
echo "Get your API key from: https://aistudio.google.com/apikey"
echo ""
read -p "Please enter your Gemini API key (starts with 'AIza'): " API_KEY
echo "======================================================================"

# Validate
if [ -z "$API_KEY" ]; then
    echo "❌ API key cannot be empty"
    exit 1
fi

if [[ ! "$API_KEY" =~ ^AIza ]]; then
    echo "❌ Invalid API key format. Google API keys start with 'AIza'"
    exit 1
fi

if [ ${#API_KEY} -lt 30 ]; then
    echo "❌ API key is too short. Google API keys are typically 39 characters"
    exit 1
fi

# Save to keychain using security command
security add-generic-password -a "IRIS" -s "GeminiAPIKey" -w "$API_KEY" -U 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ API key saved successfully!"
    echo "✅ You can now run IRIS"
else
    echo "❌ Failed to save API key to keychain"
    exit 1
fi
