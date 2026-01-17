#!/usr/bin/env swift

import Foundation
import GoogleGenerativeAI

// Test script to verify Gemini model name
print("🧪 Testing Gemini model names...")

// Get API key from UserDefaults (same as app)
let apiKey = UserDefaults.standard.string(forKey: "GEMINI_API_KEY") ?? ""

if apiKey.isEmpty {
    print("❌ No API key found in UserDefaults")
    exit(1)
}

print("✅ API key found: \(apiKey.prefix(10))...")

// Test different model names
let modelNamesToTest = [
    "gemini-flash-preview",
    "gemini-3-flash-preview",
    "gemini-2.0-flash-exp"
]

for modelName in modelNamesToTest {
    print("\n🔍 Testing model: \(modelName)")

    let model = GenerativeModel(
        name: modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
            temperature: 0.1,
            maxOutputTokens: 100
        )
    )

    let prompt = """
    Classify this as one word: "improve this code"

    Options: codeImprovement, messageReply, general

    Answer with only one word:
    """

    do {
        let response = try await model.generateContent(prompt)
        if let text = response.text {
            print("✅ SUCCESS with \(modelName)")
            print("   Response: \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
        } else {
            print("⚠️ No text response from \(modelName)")
        }
    } catch {
        print("❌ FAILED with \(modelName)")
        print("   Error: \(error)")
        if let nsError = error as NSError? {
            print("   Domain: \(nsError.domain), Code: \(nsError.code)")
        }
    }
}

print("\n🏁 Test complete")
