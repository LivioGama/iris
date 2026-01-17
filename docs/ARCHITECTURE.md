# IRIS Architecture Documentation

## System Overview

**I.R.I.S** (Intent Resolution and Inference System) is a hands-free macOS interaction system that combines eye tracking, voice recognition, and multimodal AI to enable natural computer interaction.

## Architecture Principles

1. **Modular Design**: Clear separation of concerns across 5 specialized modules
2. **Protocol-Driven**: All services defined via protocols for testability and flexibility
3. **Dependency Injection**: Centralized container manages all service instantiation
4. **Main Actor Safety**: UI operations use @MainActor for thread safety
5. **Reactive State**: Combine publishers for state propagation

## Module Architecture

### Module Dependency Graph

```
           ┌──────────────┐
           │     IRIS     │  ← Main executable
           │ (Orchestr.)  │
           └──────┬───────┘
                  │
      ┌───────────┼───────────┬───────────┐
      │           │           │           │
      ▼           ▼           ▼           ▼
┌──────────┐┌──────────┐┌──────────┐┌──────────┐
│ IRISCore ││IRISVision││ IRISGaze ││IRISMedia │
└────┬─────┘└────┬─────┘└────┬─────┘└────┬─────┘
     │           │           │           │
     │           └─────┬─────┘           │
     │                 │                 │
     └────────┬────────┴─────────────────┘
              │
      ┌───────▼────────┐
      │  IRISNetwork   │
      └────────────────┘
```

### 1. IRISCore Module

**Purpose**: Foundational types, protocols, and security

**Location**: `IRISCore/Sources/`

**Components**:

#### Models

- `ChatMessage.swift` - Message data structure for conversations
- `DetectedElement.swift` - UI element representation with bounds, label, type, confidence
- `ResolvedIntent.swift` - Intent resolution result
- `IRISError.swift` - Centralized error handling with recovery suggestions

#### Protocols

- `ServiceProtocols.swift` - Defines all service interfaces:
  - `GazeTrackingService` - Eye tracking operations
  - `AIAssistantService` - AI conversation handling
  - `ElementDetectionService` - UI element detection
  - `ScreenCaptureServiceProtocol` - Screenshot capture
  - `AudioServiceProtocol` - Audio input management
  - `SpeechRecognitionService` - Speech-to-text
  - `ScreenCaptureServiceProtocol` - Screenshot capture

#### Security

- `KeychainService.swift` - Secure API key storage using macOS Keychain
  - Singleton pattern
  - Manages Gemini API credentials
  - Thread-safe operations

#### Environment

- `PathResolver.swift` - Python environment validation and path resolution
  - Validates Python installation
  - Resolves script paths
  - Environment variable management

**Dependencies**: None (foundation module)

### 2. IRISVision Module

**Purpose**: Visual element detection and text recognition

**Location**: `IRISVision/Sources/`

**Components**:

#### Detection

- `AccessibilityDetector.swift` - Accessibility API-based element detection
  - Fast element queries
  - Window detection
  - UI hierarchy traversal

- `ComputerVisionDetector.swift` - Vision framework-based detection
  - Image-based element detection
  - Visual pattern recognition

#### Analysis

- `AccessibilityDetector.swift` - Accessibility API-based element detection

#### Text Recognition

- `VisionTextDetector.swift` - OCR using Vision framework
  - Text extraction from images
  - Layout analysis
  - Language detection

**Dependencies**: IRISCore

### 3. IRISGaze Module

**Purpose**: Eye tracking and Python process management

**Location**: `IRISGaze/Sources/`

**Components**:

#### Tracking

- `PythonProcessManager.swift` - Python process lifecycle management
  - **State Machine**: idle, starting, running, recovering, failed
  - **Health Monitoring**: 5s intervals, 10s output timeout
  - **Auto-Recovery**: Max 3 attempts with exponential backoff
  - **Process Cleanup**: Graceful termination with timeout

- `GazeEstimator.swift` - Gaze point calculation and tracking
  - Real-time gaze estimation
  - Calibration management
  - Temporal stability filtering
  - Adaptive frame rate (15-60 FPS based on load)

**Dependencies**: IRISCore, IRISVision

**Python Integration**:

- `/gaze_tracking/*.py` - Eye tracking Python modules
- Communication via JSON over stdout
- Process spawning and monitoring
- Error recovery mechanisms

### 4. IRISNetwork Module

**Purpose**: Gemini API integration and conversation management

**Location**: `IRISNetwork/Sources/`

**Components**:

#### Gemini Integration

- `GeminiClient.swift` - Low-level HTTP client
  - Model: `gemini-2.0-flash-exp`
  - JSON request/response handling
  - Error handling with retry logic

- `ConversationManager.swift` - History management with automatic pruning
  - **Pruning Strategy**: Keeps first message + last N-1 messages
  - **Default Limit**: 20 messages
  - **Memory Safety**: Bounded history prevents memory leaks

- `MessageExtractionService.swift` - Structured data extraction from responses
  - JSON parsing
  - Intent extraction
  - Entity recognition

- `PromptBuilder.swift` - Prompt construction for Gemini
  - Template management
  - Context injection
  - Image attachment handling

#### Sentiment Analysis

- `SentimentAnalysisService.swift` - Response sentiment analysis
  - Tone detection
  - Confidence scoring

**Dependencies**: IRISCore, IRISVision

### 5. IRISMedia Module

**Purpose**: Audio, camera, speech, and screen capture

**Location**: `IRISMedia/Sources/`

**Components**:

#### Audio

- `AudioService.swift` - Audio input management
  - Microphone access
  - Audio stream processing
  - Level monitoring

#### Camera

- `CameraService.swift` - Webcam capture for eye tracking
  - Camera enumeration
  - Frame capture
  - Resolution management

#### Screen Capture

- `ScreenCaptureService.swift` - Full and cropped screen capture
  - Multi-screen support
  - Region capture
  - Format conversion

- `ScreenshotService.swift` - Screenshot utilities
  - Quick capture
  - Clipboard integration

#### Speech

- `SpeechService.swift` - Speech-to-text using macOS Speech framework
  - Real-time transcription
  - Language support
  - Confidence scoring

- `VoiceInteractionService.swift` - Voice interaction handling
  - Wake word detection
  - Command parsing
  - Response generation

**Dependencies**: IRISCore

### 6. IRIS (Main App)

**Purpose**: Application orchestration and UI

**Location**: `IRIS/`

**Components**:

#### Core Orchestration

- `IRISCoordinator.swift` - Main orchestrator (@MainActor)
  - Service lifecycle management
  - Event coordination
  - State synchronization

- `DependencyContainer.swift` - Dependency injection (Singleton)
  - Service instantiation
  - Dependency resolution
  - Lifecycle management

- `IntentTrigger.swift` - State machine for intent detection
  - Trigger management
  - Intent routing
  - State transitions

- `IntentResolver.swift` - Intent resolution logic
  - Intent classification
  - Action mapping
  - Error handling

#### Services

- `GeminiAssistantOrchestrator.swift` - Gemini interaction orchestration
  - Request coordination
  - Response handling
  - Context management

#### UI Components

- `ContentView.swift` - Main overlay interface
  - SwiftUI root view
  - Layout management

- `DebugPanel.swift` - Debug information display
  - Real-time metrics
  - Log visualization

- `ContextualGazeIndicator.swift` - Gaze point visualization
  - Visual feedback
  - Animation

- `GeminiResponseOverlay.swift` - AI response display
  - Response rendering
  - Interaction handling

#### App Entry

- `IRISApp.swift` - SwiftUI app entry point
  - App lifecycle
  - Window management
  - Permission handling

**Dependencies**: All modules (IRISCore, IRISVision, IRISGaze, IRISNetwork, IRISMedia)

## Data Flow

### 1. Active Session Analysis Flow

```
IRIS active session
     ↓
IRISCoordinator triggers capture every 2 seconds
     ↓
ScreenCaptureService captures screenshot
     ↓
GeminiClient sends image + context to Gemini API
     ↓
Gemini analyzes and responds
     ↓
EtherealFloatingOverlay displays result
```

### 2. Gaze Tracking Flow

```
Python Eye Tracker (subprocess)
     ↓
PythonProcessManager parses JSON output
     ↓
GazeEstimator updates gaze point
     ↓
ContextualGazeIndicator renders visual feedback
     ↓
AccessibilityDetector finds element at gaze point
     ↓
DebugPanel shows detected element info
```

### 3. Voice Command Flow

```
User speaks
     ↓
AudioService captures audio
     ↓
SpeechService transcribes to text
     ↓
GeminiAssistantOrchestrator processes request
     ↓
GeminiClient sends to API
     ↓
Response displayed in UI
```

## State Management

### Process State Machine (PythonProcessManager)

```
idle ──start()──> starting ──success──> running
 ↑                                         │
 │                                    crashed/error
 │                                         ↓
 └──max attempts──< recovering <──recovery attempt
                         │
                    max attempts
                         ↓
                      failed
```

### Application Lifecycle

1. **Initialization**: IRISCoordinator creates all core services
2. **Setup**: Services configure and validate dependencies
3. **Ready**: Main loop starts, Python subprocess launches
4. **Running**: Event processing, gaze tracking, continuous screen analysis
5. **Shutdown**: Graceful cleanup, Python process termination

## Communication Patterns

### 1. Service Communication

- **Protocols**: All services implement protocol interfaces
- **Callbacks**: Closures for async operations
- **Combine Publishers**: Reactive state updates
- **Delegates**: UI event handling

### 2. Process Communication

- **Python → Swift**: JSON over stdout
- **Swift → Python**: Command-line arguments
- **Health Checks**: Periodic heartbeat monitoring

### 3. API Communication

- **HTTP**: RESTful requests to Gemini API
- **JSON**: Request/response serialization
- **Async/Await**: Modern concurrency for network calls

## Performance Optimizations

### 1. Adaptive Frame Rate (GazeEstimator)

- **High Performance Mode**: 60 FPS (simple UI, no heavy processing)
- **Low Power Mode**: 15 FPS (heavy processing active)
- **Auto-switching**: Based on workload detection

### 2. Memory Management

- **Conversation Pruning**: ConversationManager bounds history to prevent leaks
- **Weak References**: Avoid retain cycles in closures
- **Resource Cleanup**: Explicit deallocation in deinit

### 3. Thread Safety

- **Main Actor**: UI operations on main thread
- **Dispatch Queues**: Background processing for I/O
- **NSLock**: Critical section protection

## Security Considerations

### 1. API Key Management

- **Keychain Storage**: Secure storage via macOS Keychain
- **No Hardcoding**: Keys never in source code
- **Access Control**: Restricted to app only

### 2. Process Isolation

- **Sandboxing**: Python process runs with minimal permissions
- **Input Validation**: All external input sanitized
- **Error Boundaries**: Failures contained to modules

### 3. Privacy

- **On-Device Processing**: Gaze tracking locally
- **Minimal Data**: Only necessary info sent to Gemini
- **User Consent**: Explicit permission for camera/mic

## Testing Strategy

### 1. Unit Tests

- **Module Tests**: Each module independently tested
- **Protocol Mocks**: Testable service implementations
- **Coverage**: >80% for critical paths

### 2. Integration Tests

- **Cross-Module**: Test module interactions
- **End-to-End**: Complete workflows
- **Performance**: Benchmarks for critical operations

### 3. Manual Testing

- **Accessibility**: Real-world usage scenarios
- **Error Recovery**: Failure handling
- **Performance**: Frame rate, latency monitoring

## Future Architecture Enhancements

- [ ] Plugin system for extensibility
- [ ] Multi-user support
- [ ] Cloud sync for conversation history
- [ ] Advanced intent recognition
- [ ] Custom model integration
- [ ] Accessibility API enhancements

## Related Documentation

- [Testing Guide](./TESTING.md)
- [API Documentation](./API.md)
- [Developer Setup](./DEVELOPER_SETUP.md)
- [Phase Summaries](../README.md)
