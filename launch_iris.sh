#!/bin/bash

# Launch IRIS with environment variables from current shell
# This ensures the Gemini API key is available to the app

# Source .zshrc to get environment variables
if [ -f ~/.zshrc ]; then
    source ~/.zshrc
fi

# Check if GEMINI_API_KEY is set
if [ -z "$GEMINI_API_KEY" ]; then
    echo "⚠️  GEMINI_API_KEY not set in environment"
    echo "Please add to ~/.zshrc:"
    echo 'export GEMINI_API_KEY="your-key-here"'
    exit 1
fi

# Launch IRIS with environment
open -a "$HOME/Applications/IRIS.app" --env GEMINI_API_KEY="$GEMINI_API_KEY"

echo "✅ IRIS launched with API key from environment"
