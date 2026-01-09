# I.R.I.S

**Intent Resolution and Inference System**

A hands-free macOS interaction system using approximate eye focus, voice commands, and Gemini 3 multimodal reasoning.

## Requirements

- macOS 14.0+
- Webcam
- Microphone
- Gemini API key

## Setup

1. Set your Gemini API key:
```bash
export GEMINI_API_KEY="your-api-key"
```

2. Build and run:
```bash
swift build
swift run IRIS
```

## Permissions

The app requires:
- Camera access (eye tracking)
- Microphone access (voice commands)
- Speech recognition (transcription)
- Screen recording (context capture)

## Usage

1. Launch the app
2. Toggle "Eye Tracking" from the menu bar
3. Look at any UI element on screen
4. Speak a natural command (e.g., "click this", "what is this?")
5. I.R.I.S will resolve your intent using Gemini 3

## Architecture

```
IRIS/
├── Core/
│   ├── IRISCoordinator.swift    # Main orchestrator
│   ├── IntentTrigger.swift      # State machine
│   ├── IntentResolver.swift     # Resolution logic
│   └── PromptBuilder.swift      # Gemini prompts
├── Services/
│   ├── CameraService.swift      # Webcam capture
│   ├── GazeEstimator.swift      # Eye tracking
│   ├── AudioService.swift       # VAD
│   ├── SpeechService.swift      # STT
│   ├── ScreenCaptureService.swift
│   └── GeminiService.swift      # API client
└── UI/
    ├── ContentView.swift        # Main overlay
    └── DebugPanel.swift         # Debug info
```
