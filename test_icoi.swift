#!/usr/bin/env swift

import Foundation

// Simple test for ICOI intent classification
print("🧪 Testing ICOI Intent Classification")

let service = IntentClassificationService()

// Test cases for each intent type
let testCases: [(input: String, expectedIntent: ICOIIntent)] = [
    // Message Reply
    ("respond to this message", .messageReply),
    ("what should I say back", .messageReply),
    ("répondre à ce message", .messageReply),

    // Code Improvement
    ("improve this code", .codeImprovement),
    ("make this code better", .codeImprovement),
    ("refactor this function", .codeImprovement),

    // Summarization
    ("summarize this meeting", .summarize),
    ("what are the key points", .summarize),
    ("résumer cette réunion", .summarize),

    // Tone Feedback
    ("analyze the tone", .toneFeedback),
    ("rewrite this professionally", .toneFeedback),
    ("make it more formal", .toneFeedback),

    // Chart Analysis
    ("explain this graph", .chartAnalysis),
    ("what does this chart show", .chartAnalysis),
    ("analyze this data", .chartAnalysis),

    // General (fallback)
    ("hello world", .general),
    ("what time is it", .general),
    ("random question", .general)
]

print("\n📊 Test Results:")
print("Input → Classified Intent (Confidence)")
print("─" * 50)

var correct = 0
var total = testCases.count

for (input, expected) in testCases {
    let result = service.classifyIntent(input: input)
    let isCorrect = result.intent == expected
    let status = isCorrect ? "✅" : "❌"

    print("\(status) \"\(input)\" → \(result.intent.rawValue) (\(String(format: "%.2f", result.confidence)))")

    if isCorrect {
        correct += 1
    }
}

print("─" * 50)
print("🎯 Accuracy: \(correct)/\(total) (\(String(format: "%.1f", Double(correct)/Double(total) * 100)))%")

// Test ICOI response parsing
print("\n🧪 Testing ICOI Response Parsing")

let parser = ICOIResponseParser()

let testResponse = """
## Improved Code
```swift
func calculateTotal(items: [Item]) -> Double {
    return items.reduce(0) { $0 + $1.price }
}
```

## What's Better
- Added type annotations for clarity
- Used reduce instead of for loop
- More concise and readable

**Option 1: Empathetic**
I understand this must be frustrating for you...

**Option 2: Concise**
Got it, I'll look into this right away.

**Option 3: Assertive**
I need you to provide more specific details.
"""

let parsed = parser.parse(responseText: testResponse)

print("📋 Parsed Response:")
print("  - Has Options: \(parsed.hasOptions)")
print("  - Has Code Block: \(parsed.hasCodeBlock)")
print("  - Has Action Items: \(parsed.hasActionItems)")
print("  - Number of Options: \(parsed.numberedOptions.count)")
print("  - Code Language: \(parsed.codeBlock?.language ?? "none")")

print("\n✅ ICOI Core Infrastructure Test Complete!")