# IRIS Blink Assistant - Gemini Integration

## Overview

IRIS now includes a blink-activated AI assistant powered by Gemini 2.0 Flash. You can trigger visual analysis by closing your eyes for 2 seconds, then speak your question.

## Features

- **Long Blink Detection**: Close your eyes for 2 seconds to trigger the assistant
- **Screenshot Capture**: Automatically captures the full screen when blink is detected
- **Voice Prompt**: Records your voice for 5 seconds after blink detection
- **Gemini Analysis**: Sends screenshot and voice prompt to Gemini 2.0 Flash multimodal API
- **On-Screen Display**: Shows the AI response in a beautiful overlay

## Setup

### 1. Set Gemini API Key

You need a Gemini API key to use this feature. Get one from:
https://aistudio.google.com/app/apikey

Then set it as an environment variable:

```bash
export GEMINI_API_KEY="your-api-key-here"
```

To make it permanent, add it to your `~/.zshrc` or `~/.bash_profile`:

```bash
echo 'export GEMINI_API_KEY="your-api-key-here"' >> ~/.zshrc
```

### 2. Grant Permissions

The app requires the following permissions:
- **Camera**: For eye tracking
- **Microphone**: For voice prompts
- **Speech Recognition**: For transcribing your voice
- **Screen Recording**: For capturing screenshots
- **Accessibility**: For detecting UI elements

macOS will prompt for these when you first run the app.

## Usage

### Triggering the Assistant

1. **Close Your Eyes**: Keep your eyes closed for 1 second
2. **Screenshot Captured**: The screen is captured and displayed
3. **Wait for Audio Cue**: You'll hear the app is listening
4. **Speak Your Question**: Speak naturally - the app will detect when you stop talking
   - Example: "What's in this image?"
   - Example: "Summarize this webpage"
   - Example: "What am I looking at?"
   - **Live Transcription**: Your speech appears in real-time as you speak
   - **Automatic Stop**: Recording stops 2 seconds after you finish speaking
5. **View Response**: The AI response appears on screen alongside the screenshot

### What Gets Sent to Gemini

- **Full Screenshot**: The entire screen at the moment of blink detection
- **Focused Element**: If you're looking at a specific UI element, it's included in the prompt
- **Voice Prompt**: Your spoken question/instruction

### Dismissing the Response

Click the X button in the top-right corner of the response overlay to dismiss it.

## Example Use Cases

### Reading Assistance
- Close eyes for 2 seconds while looking at text
- Ask: "Read this text to me"
- Gemini will extract and read the visible text

### Visual Description
- Close eyes for 2 seconds
- Ask: "Describe what you see"
- Gemini provides a detailed description of the screen

### Web Summarization
- Close eyes while browsing
- Ask: "Summarize this article"
- Gemini reads and summarizes the content

### Code Review
- Close eyes while viewing code
- Ask: "Review this code for bugs"
- Gemini analyzes the code and provides feedback

### Translation
- Close eyes for 2 seconds
- Ask: "Translate this to Spanish"
- Gemini translates visible text

## Technical Details

### Blink Detection Parameters

- **Eye Aspect Ratio Threshold**: 0.21 (eyes considered closed)
- **Long Blink Duration**: 1 second (30 frames at 30fps)
- **Cursor Freeze**: During normal blinks, cursor movement is paused
- **Progress Feedback**: Status updates every 10 frames (every ~0.33 seconds)

### Voice Recognition

- **Duration**: Automatic stop after 2 seconds of silence
- **Language**: English (US) by default
- **Live Transcription**: Full real-time speech-to-text display
- **Silence Detection**: Intelligently detects when you've finished speaking

### API Configuration

- **Model**: Gemini 2.0 Flash Experimental
- **Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent`
- **Image Format**: JPEG with 80% compression
- **Context**: Includes focused element information when available

## Troubleshooting

### "GEMINI_API_KEY not set" Error

Make sure you've exported the environment variable before running the app:

```bash
export GEMINI_API_KEY="your-key-here"
./.build/debug/IRIS
```

### Audio Engine Already Running

If you trigger multiple blinks in quick succession, the second one will be skipped. Wait for the first analysis to complete.

### No Response from Gemini

Check:
1. API key is valid
2. Internet connection is working
3. Gemini API quota hasn't been exceeded

### Microphone Not Working

Grant microphone permission in:
System Settings → Privacy & Security → Microphone → Enable for IRIS

### Speech Recognition Fails

Grant speech recognition permission in:
System Settings → Privacy & Security → Speech Recognition → Enable for IRIS

## Building and Running

```bash
# Build
cd /Users/livio/Documents/iris2
swift build

# Run with API key
export GEMINI_API_KEY="your-key-here"
./.build/debug/IRIS
```

## Privacy

- Screenshots are sent to Google Gemini API
- Voice recordings are processed by Apple's Speech Recognition
- No data is stored locally
- Review Google's privacy policy: https://policies.google.com/privacy

## Cost Considerations

Gemini 2.0 Flash pricing (as of 2025):
- Text input: Free for prompts under 128k tokens
- Image input: May incur costs based on resolution

Monitor your usage at: https://aistudio.google.com/

## Keyboard Shortcuts

None currently - all interaction is eye-controlled.

## Limitations

- Requires stable internet connection
- API rate limits apply
- Voice recognition quality depends on microphone
- Works best in quiet environments
- 2-second blink may be tiring for frequent use

## Future Enhancements

Possible improvements:
- Configurable blink duration
- Offline mode with local models
- Voice command history
- Custom prompts/macros
- Multi-language support
- Adjustable screenshot region

## Support

For issues or questions, check the main IRIS README or submit an issue on GitHub.
