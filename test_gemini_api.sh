#!/bin/bash

# Test Gemini API model names
API_KEY="${GEMINI_API_KEY}"

if [ -z "$API_KEY" ]; then
    echo "❌ No API key found in UserDefaults"
    exit 1
fi

echo "✅ API key found: ${API_KEY:0:10}..."

# Test different model names
models=(
    "gemini-flash-preview"
    "gemini-3-flash-preview"
    "gemini-2.0-flash-exp"
)

for model in "${models[@]}"; do
    echo ""
    echo "🔍 Testing model: $model"

    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${API_KEY}" \
        -H 'Content-Type: application/json' \
        -d '{
            "contents": [{
                "parts": [{
                    "text": "Classify this as one word: improve this code. Options: codeImprovement, messageReply, general. Answer with only one word:"
                }]
            }],
            "generationConfig": {
                "temperature": 0.1,
                "maxOutputTokens": 100
            }
        }')

    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    body=$(echo "$response" | sed '/HTTP_CODE:/d')

    if [ "$http_code" = "200" ]; then
        echo "✅ SUCCESS with $model"
        echo "$body" | jq -r '.candidates[0].content.parts[0].text // "No text"' 2>/dev/null || echo "$body"
    else
        echo "❌ FAILED with $model (HTTP $http_code)"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    fi
done

echo ""
echo "🏁 Test complete"
