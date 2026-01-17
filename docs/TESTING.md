# IRIS Testing Guide

## Overview

This document describes the testing strategy and implementation for the IRIS (Intent Resolution and Inference System) project.

## Test Structure

The project uses Swift Package Manager's testing framework (XCTest) with tests organized into four test targets:

```
Tests/
├── IRISCoreTests/           # Core module unit tests
├── IRISNetworkTests/        # Network module unit tests
├── IRISGazeTests/          # Gaze tracking module unit tests
└── IRISIntegrationTests/   # Integration tests
```

## Running Tests

### Run All Tests

```bash
swift test
```

### Run Specific Test Suite

```bash
swift test --filter ConversationManagerTests
swift test --filter GeminiClientTests
swift test --filter PythonProcessManagerTests
swift test --filter KeychainServiceTests
```

### Run in Parallel

```bash
swift test --parallel
```

## Unit Tests

### 1. ConversationManager Tests

**Location:** `Tests/IRISNetworkTests/ConversationManagerTests.swift`

**Coverage:**
- History pruning logic
- Message addition and retrieval
- Clear history functionality
- Custom max history length
- Edge cases (empty history, single message, large excess)

**Key Test Cases:**
- `testHistoryPruningKeepsFirstMessage` - Verifies first message is always preserved
- `testHistoryPruningKeepsRecentMessages` - Ensures recent messages are retained
- `testHistoryPruningWithLargeExcess` - Tests behavior with many messages
- `testClearHistory` - Validates history clearing

**Running:**
```bash
swift test --filter ConversationManagerTests
```

### 2. PythonProcessManager Tests

**Location:** `Tests/IRISGazeTests/PythonProcessManagerTests.swift`

**Coverage:**
- Process lifecycle management
- State transitions
- Health monitoring
- Error handling
- Recovery mechanisms
- Callback system

**Key Test Cases:**
- `testInitialStateIsIdle` - Verifies initial state
- `testStateTransitions` - Tests state machine
- `testProcessErrorDescriptions` - Validates error messages
- `testOnStateChangeCallback` - Tests callback invocation
- `testMultipleInstances` - Ensures multiple managers can coexist

**Running:**
```bash
swift test --filter PythonProcessManagerTests
```

### 3. KeychainService Tests

**Location:** `Tests/IRISCoreTests/KeychainServiceTests.swift`

**Coverage:**
- API key encryption/decryption
- Save, retrieve, and delete operations
- Data encoding (empty strings, special characters, Unicode)
- Thread safety
- Error handling

**Key Test Cases:**
- `testSaveAndRetrieveAPIKey` - Basic save/retrieve flow
- `testUpdateAPIKey` - Tests key updates
- `testDeleteAPIKey` - Validates deletion
- `testSaveSpecialCharacters` - Tests encoding edge cases
- `testConcurrentReadWrite` - Thread safety validation

**Running:**
```bash
swift test --filter KeychainServiceTests
```

### 4. GeminiClient Tests

**Location:** `Tests/IRISNetworkTests/GeminiClientTests.swift`

**Coverage:**
- HTTP request construction
- Response parsing
- Error handling
- Request/response model encoding/decoding
- Multipart messages (text + images)

**Key Test Cases:**
- `testMissingAPIKeyError` - Validates API key validation
- `testGeminiRequestEncoding` - Tests request serialization
- `testGeminiResponseDecoding` - Tests response parsing
- `testGeminiRequestWithInlineData` - Tests image attachments
- `testErrorDescriptions` - Validates error messages

**Running:**
```bash
swift test --filter GeminiClientTests
```

## Integration Tests

### 1. Gaze Tracking Integration

**Location:** `Tests/IRISIntegrationTests/GazeTrackingIntegrationTests.swift`

**Coverage:**
- PythonProcessManager lifecycle
- State callbacks
- Error handling
- Recovery mechanisms
- GazeEstimator initialization
- Memory management

**Key Test Cases:**
- `testPythonProcessManagerLifecycle` - End-to-end lifecycle
- `testPythonProcessManagerStateCallbacks` - State change notifications
- `testPythonProcessManagerErrorHandling` - Error scenarios
- `testGazeEstimatorCallbacks` - Callback system
- `testProcessManagerDeallocation` - Memory leak detection

### 2. Element Detection Integration

**Location:** `Tests/IRISIntegrationTests/ElementDetectionIntegrationTests.swift`

**Coverage:**
- Detector initialization
- DetectedElement model
- Array operations and filtering
- Screen region detection
- Element overlap detection
- Performance benchmarks

**Key Test Cases:**
- `testAccessibilityDetectorInitialization` - Detector setup
- `testDetectedElementCreation` - Model creation
- `testElementSortingByConfidence` - Sorting logic
- `testElementsInScreenRegions` - Screen quadrant detection
- `testElementArrayPerformance` - Performance validation

### 3. Gemini Integration

**Location:** `Tests/IRISIntegrationTests/GeminiIntegrationTests.swift`

**Coverage:**
- Voice command to Gemini response flow
- Blink detection workflow
- Conversation management
- Error handling
- Long conversations with pruning
- Concurrent operations

**Key Test Cases:**
- `testConversationManagerWithGeminiClient` - Basic flow
- `testBlinkDetectionMessageFlow` - Blink workflow
- `testMultipleBlinkDetectionCycle` - Multiple blinks
- `testGeminiClientErrorHandlingWithConversation` - Error scenarios
- `testLongConversationWithPruning` - History management

## Test Coverage

### Unit Test Coverage

| Module | Tests | Coverage |
|--------|-------|----------|
| ConversationManager | 14 | History pruning, message management |
| PythonProcessManager | 20+ | Lifecycle, state management, health checks |
| KeychainService | 18+ | Encryption, storage, thread safety |
| GeminiClient | 16 | HTTP, serialization, error handling |

### Integration Test Coverage

| Area | Tests | Coverage |
|------|-------|----------|
| Gaze Tracking | 15 | Process management, callbacks, memory |
| Element Detection | 18 | Detectors, models, performance |
| Gemini Integration | 12+ | Conversations, blinks, errors |

## Writing New Tests

### Test Naming Convention

```swift
func test<Component><Scenario>() {
    // Test implementation
}
```

Examples:
- `testConversationPruningKeepsFirstMessage`
- `testPythonProcessManagerRecoveryAttempt`
- `testKeychainSaveAndRetrieve`

### Test Structure

```swift
// 1. Setup
let manager = ConversationManager(maxHistoryLength: 5)

// 2. Execute
for i in 1...10 {
    manager.addMessage(createTestMessage(text: "Message \(i)"))
}

// 3. Verify
XCTAssertEqual(manager.count, 5)
XCTAssertEqual(manager.getHistory()[0].parts[0].text, "Message 1")
```

### Async Tests

```swift
func testAsyncOperation() async {
    let client = GeminiClient(apiKey: "")

    do {
        _ = try await client.sendRequest(request)
        XCTFail("Should have thrown error")
    } catch let error as GeminiError {
        XCTAssertEqual(error, .missingAPIKey)
    }
}
```

### Testing Callbacks

```swift
func testCallback() {
    let expectation = self.expectation(description: "Callback invoked")
    var callbackInvoked = false

    manager.onStateChange = { state in
        callbackInvoked = true
        expectation.fulfill()
    }

    manager.stop()

    wait(for: [expectation], timeout: 1.0)
    XCTAssertTrue(callbackInvoked)
}
```

## Continuous Integration

Tests are automatically run:
- On every commit
- Before merges
- As part of the build verification process

## Test Best Practices

1. **Isolation**: Each test should be independent and not rely on others
2. **Cleanup**: Always clean up resources in `tearDown()`
3. **Naming**: Use descriptive names that explain what is being tested
4. **Coverage**: Aim for high coverage of critical paths
5. **Speed**: Keep tests fast; use mocks for slow operations
6. **Assertions**: Use specific assertions (`XCTAssertEqual` vs `XCTAssertTrue`)

## Known Limitations

1. **Keychain Tests**: Run on macOS only due to Keychain dependency
2. **Python Process Tests**: Require Python environment setup
3. **Accessibility Tests**: May require accessibility permissions

## Troubleshooting

### Tests Failing with Permission Errors

Ensure accessibility permissions are granted:
```bash
System Settings → Privacy & Security → Accessibility
```

### Tests Timing Out

Increase timeout for slow operations:
```swift
wait(for: [expectation], timeout: 5.0)  // Increased from 1.0
```

### Memory Leak Warnings

Use weak references in closures:
```swift
manager.onStateChange = { [weak self] state in
    self?.handleStateChange(state)
}
```

## Future Test Enhancements

- [ ] Add performance benchmarks
- [ ] Increase code coverage to 90%+
- [ ] Add UI tests for SwiftUI components
- [ ] Add snapshot tests for visual components
- [ ] Implement continuous coverage monitoring
- [ ] Add stress tests for long-running operations

## Test Metrics

Current test statistics:
- **Total Tests**: 90+
- **Unit Tests**: 68+
- **Integration Tests**: 45+
- **Average Test Duration**: <0.1s
- **Total Test Suite Duration**: ~5-10s

## Related Documentation

- [Architecture Documentation](./ARCHITECTURE.md)
- [API Documentation](./API.md)
- [Developer Setup Guide](./DEVELOPER_SETUP.md)
- [Phase 10 Summary](../PHASE_10_SUMMARY.md)
