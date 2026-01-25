# I.R.I.S

**Intent Resolution and Inference System**

A hands-free macOS interaction system using eye tracking, voice commands, and Gemini multimodal reasoning. IRIS can analyze what you're looking at, suggest helpful actions, and **execute them automatically**.

## Features

- **Eye Tracking** - Knows where you're looking on screen
- **Voice Commands** - Natural language interaction
- **Screenshot Analysis** - Gemini understands screen context
- **Proactive Suggestions** - AI suggests relevant actions based on what you see
- **Agentic Skills** - IRIS can ACT, not just display (copy code, open URLs, run commands)

## Requirements

- macOS 14.0+
- Webcam (for eye tracking)
- Microphone (for voice commands)
- Gemini API key

## Quick Start

### 1. Set your Gemini API key

```bash
export GEMINI_API_KEY="your-api-key"
```

Or configure it in the app's menu bar settings.

### 2. Build and run

```bash
./build_and_install.sh
```

This builds and installs IRIS to `~/Applications/IRIS.app`.

### 3. Grant permissions

On first launch, grant these permissions in System Settings > Privacy & Security:

| Permission | Why |
|------------|-----|
| Camera | Eye tracking via webcam |
| Microphone | Voice commands |
| Screen Recording | Capture what you're looking at |
| Accessibility | Control apps, type text, automation |

### 4. Start using IRIS

1. Launch IRIS from `~/Applications/IRIS.app`
2. A gaze indicator appears showing where you're looking
3. **Right wink** to capture screenshot and get suggestions
4. Say a number ("one", "two") to select a suggestion, or speak a custom request
5. **Left wink** to toggle eye tracking on/off

## Agentic Skills

IRIS includes an **agentic skills system** that allows it to take actions on your behalf, not just display information.

### How It Works

1. When you wink, IRIS captures a screenshot
2. Gemini analyzes the screen and suggests actions
3. Each suggestion is matched to a **skill** that can execute it
4. High-confidence actions (like search) auto-execute
5. Other actions copy results to clipboard or await confirmation

### Available Skills

| Skill | Trigger | What It Does | Auto-Execute |
|-------|---------|--------------|--------------|
| **Web Search** | Selected text | Opens Google search | Yes (95%+) |
| **Code Improvement** | Code visible | Refactors and copies to clipboard | No |
| **Bug Fixer** | Error messages | Analyzes and suggests fix | No |
| **Code Explainer** | Code visible | Explains what code does | Yes (80%+) |
| **Content Summarizer** | Long text | Extracts key points | Yes (80%+) |
| **Message Composer** | Chat/email | Drafts a reply | No |
| **Code Generator** | Empty editor | Generates boilerplate | No |
| **Translator** | Foreign text | Translates content | No |
| **Data Analyzer** | Charts/data | Provides insights | No |
| **Autocomplete** | Partial text | Completes content | No |

### Enabling Agentic Features

Agentic features are **enabled by default** in proactive mode. To use them:

1. **Ensure Accessibility permission is granted** - Required for AppleScript automation
2. **Right wink** at something on screen
3. Wait for suggestions to appear
4. Suggestions with a skill match show what action will be taken
5. Say the number to execute, or speak a custom request

### Auto-Execute Behavior

Some skills auto-execute when confidence is high enough:

- **Web Search**: If text is selected, automatically opens Google (95%+ confidence)
- **Explain/Summarize**: Auto-executes at 80%+ confidence since they're read-only

To disable auto-execute, the skill would need to be modified in `SkillRegistry.swift`.

### Debug Mode

In DEBUG builds, a skill badge appears showing:
- Which skill matched the suggestion
- Confidence percentage
- Whether IRIS can act on it
- What action will be taken

## Architecture

```
IRIS/
├── Core/
│   ├── IRISCoordinator.swift       # Main orchestrator
│   ├── IntentTrigger.swift         # State machine
│   └── IntentResolver.swift        # Resolution logic
├── Services/
│   ├── GeminiAssistantOrchestrator.swift  # Gemini + skills integration
│   ├── ActionExecutor.swift        # Executes actions
│   ├── AppleScriptBridge.swift     # macOS automation
│   ├── ActionPlanner.swift         # Plans multi-step actions
│   └── ProactiveIntentPromptBuilder.swift # AI prompts
├── Skills/
│   ├── SkillRegistry.swift         # All available skills
│   └── SkillLoader.swift           # Skill loading system
└── UI/
    ├── EtherealFloatingOverlay.swift  # Main overlay UI
    ├── DebugSkillBadge.swift          # Skill debug info
    └── ProactiveSuggestionsView.swift # Suggestion cards

IRISCore/
└── Sources/Models/
    ├── Skill.swift                 # Skill model
    └── ProactiveSuggestion.swift   # Suggestion with skill info
```

## Voice Commands

| Command | Action |
|---------|--------|
| "one" / "two" / "three" | Select suggestion by number |
| "stop" / "cancel" | Close overlay |
| Any other phrase | Custom request to Gemini |

## Customizing Skills

Skills are defined in `IRIS/Skills/SkillRegistry.swift`. Each skill has:

```swift
Skill(
    id: "skill-id",
    name: "Display Name",
    description: "When to use this skill",
    icon: "sf.symbol.name",
    intents: ["matching", "intent", "keywords"],
    capabilities: [.readScreen, .clipboard, .executeShell],
    allowedActions: [.copy, .paste, .openUrl, .runCommand],
    canAutoExecute: false,
    autoExecuteThreshold: 0.9
)
```

### Adding a New Skill

1. Add the skill definition in `SkillRegistry.registerBuiltInSkills()`
2. Add planning logic in `ActionPlanner.planActions()` for the skill ID
3. The skill will automatically match based on its `intents` array

## Troubleshooting

### Permissions not working after rebuild

macOS tracks permissions by code signature. With ad-hoc signing, each rebuild changes the signature. Either:
- Re-grant permissions after each rebuild (during development)
- Use a Developer ID certificate for stable signatures

### Eye tracking not accurate

- Ensure good lighting on your face
- Position webcam at eye level
- Calibration happens automatically over time

### Gemini not responding

- Check your API key is set correctly
- Verify network connectivity
- Check the debug log at `/tmp/iris_startup.log`

## Development

### Building

```bash
# Build and install (recommended)
./build_and_install.sh

# Or build with Xcode
xcodebuild -scheme IRIS -configuration Debug -destination "platform=macOS" build
```

### Logs

- Startup log: `/tmp/iris_startup.log`
- Blink debug: `/tmp/iris_blink_debug.log`
- Screenshot debug: `/tmp/iris_debug_screenshot.png`

## License

MIT

## Acknowledgments

- Google Gemini for multimodal AI
- Apple for Vision framework and Speech recognition
