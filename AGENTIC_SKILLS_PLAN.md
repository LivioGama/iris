# IRIS Agentic Skills Integration Plan

## Executive Summary

Transform IRIS from a **display-only assistant** into an **agentic system** that can ACT, inspired by Claude Code's skills architecture. The goal is to dynamically deliver skills based on screen context without user configuration.

## Implementation Status

### Completed (Phase 1-3)

#### Phase 1: Skill Registry & Intent Mapping

**1.1 Skill Model** - `IRISCore/Sources/Models/Skill.swift`
- `Skill` struct with id, name, description, icon, intents, capabilities, allowedActions
- `SkillCapability` enum: readScreen, executeShell, controlApps, webSearch, clipboard, fileSystem, apiCalls, typeText
- `SkillActionType` enum: copy, paste, typeText, click, pressKey, openUrl, openApp, runCommand, etc.
- `Action`, `ActionStep`, `ActionPlan` for structured execution
- `ActionResult`, `ExecutionResult` for tracking outcomes

**1.2 Skill Registry** - `IRIS/Skills/SkillRegistry.swift`
- Central registry of all available skills
- 10 built-in skills registered
- Intent-to-skill mapping
- Suggestion enrichment with skill metadata

**1.3 Skill Loader** - `IRIS/Skills/SkillLoader.swift`
- Progressive loading (metadata at startup, full skill on activation)
- Skill matching based on context and suggestions
- Capability checking

#### Phase 2: Execution Layer

**2.1 Action Executor** - `IRIS/Services/ActionExecutor.swift`
- Executes all action types
- Clipboard operations (copy, paste)
- URL opening
- Shell command execution
- Notification display
- Speech synthesis

**2.2 AppleScript Bridge** - `IRIS/Services/AppleScriptBridge.swift`
- App activation/control
- Text typing
- Keystroke simulation
- Mouse control (click, move, right-click)
- System notifications
- iMessage, Calendar, Mail integration
- Finder control

**2.3 Action Planner** - `IRIS/Services/ActionPlanner.swift`
- Generates action plans from skills
- Skill-specific planning (web search, code improvement, message compose, etc.)
- Plan execution with fallback support
- Quick action helpers

#### Phase 3: Enhanced Intent Detection

**3.1 ProactiveIntentPromptBuilder Updates**
- Added skill awareness to Gemini prompt
- Skill table in system prompt
- Response format includes matched_skill, can_act, action_preview

**3.2 ProactiveSuggestion Model Updates**
- Added `matchedSkill: String?`
- Added `canAct: Bool`
- Added `actionPreview: String?`
- Added `showsExecuteButton` and `shouldAutoExecute` computed properties

**3.3 Debug Badge System** - `IRIS/UI/DebugSkillBadge.swift`
- Shows skill info in DEBUG builds
- Expandable details (capabilities, actions, auto-execute threshold)
- Skill indicator for compact display

### Built-in Skills

| Skill ID | Name | Intents | Capabilities | Auto-Execute |
|----------|------|---------|--------------|--------------|
| `code-improvement` | Code Improvement | improve, refactor | readScreen, clipboard | No |
| `bug-fixer` | Bug Fixer | fix, debug, bugs | readScreen, clipboard, executeShell | No |
| `code-explainer` | Code Explainer | explain | readScreen | Yes @ 80% |
| `content-summarizer` | Content Summarizer | summarize, tldr | readScreen, clipboard | Yes @ 80% |
| `message-composer` | Message Composer | reply, respond | readScreen, clipboard, controlApps, typeText | No |
| `web-search` | Web Search | search | readScreen, webSearch | Yes @ 95% |
| `code-generator` | Code Generator | generate | readScreen, clipboard, fileSystem | No |
| `translator` | Translator | translate | readScreen, clipboard | No |
| `data-analyzer` | Data Analyzer | analyze | readScreen, clipboard | No |
| `completer` | Autocomplete | complete | readScreen, clipboard, typeText | No |

---

## Next Steps (Phase 4-5)

### Phase 4: Full Skill Execution Flow

#### 4.1 Wire Skill Execution After Gemini Response

Currently, after Gemini responds, the response is displayed. To enable action execution:

**File:** `IRIS/Services/GeminiAssistantOrchestrator.swift`

```swift
// After Gemini response is received, check if we should execute actions
private func handleSkillExecution(
    suggestion: ProactiveSuggestion,
    geminiResponse: String
) async {
    guard let skillId = suggestion.matchedSkill,
          let skill = skillRegistry.skill(for: skillId),
          suggestion.canAct else {
        return
    }

    // Create screen context from current state
    let context = ScreenContext.from(context: detectedContext)

    // Generate action plan
    let plan = try await actionPlanner.planActions(
        skill: skill,
        context: context,
        userRequest: suggestion.label,
        geminiResponse: geminiResponse
    )

    // Check if confirmation is needed
    if plan.requiresConfirmation && suggestion.confidence < 0.9 {
        // Show confirmation UI
        await showExecutionConfirmation(plan: plan)
    } else {
        // Execute directly
        let result = try await actionPlanner.executePlan(plan)
        await handleExecutionResult(result)
    }
}
```

#### 4.2 Add Voice Commands for Execution

**File:** `IRIS/Services/GeminiAssistantOrchestrator.swift`

Add to `parseSuggestionSelection`:

```swift
// Check for execution commands
let executeCommands = ["do it", "execute", "yes", "go", "run it", "make it so"]
if executeCommands.contains(where: { normalized.contains($0) }) {
    // Execute the first/selected suggestion
    return .execute
}

let previewCommands = ["show me", "preview", "what will happen"]
if previewCommands.contains(where: { normalized.contains($0) }) {
    return .preview
}

let cancelCommands = ["stop", "cancel", "nevermind", "undo"]
if cancelCommands.contains(where: { normalized.contains($0) }) {
    return .cancel
}
```

#### 4.3 Execution Confirmation UI

**File:** `IRIS/UI/ExecutionConfirmationView.swift` (new)

```swift
struct ExecutionConfirmationView: View {
    let plan: ActionPlan
    let skill: Skill
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Skill header
            HStack {
                Image(systemName: skill.icon)
                Text(skill.name)
            }

            // Action preview
            Text("This will:")
            ForEach(plan.steps) { step in
                HStack {
                    Image(systemName: "arrow.right")
                    Text(step.description)
                }
            }

            // Buttons
            HStack {
                Button("Cancel") { onCancel() }
                Button("Execute") { onConfirm() }
            }
        }
    }
}
```

### Phase 5: Advanced Features

#### 5.1 Execution Feedback Loop

After executing an action, verify the result and offer follow-up:

```swift
private func handleExecutionResult(_ result: ExecutionResult) async {
    if result.overallSuccess {
        // Show success notification
        await actionExecutor.execute(Action.notify("Done!", title: skill.name))

        // Offer follow-up
        await MainActor.run {
            self.proactiveSuggestions = generateFollowUpSuggestions(for: result)
        }
    } else {
        // Show error and offer retry/alternative
        let errorMessage = result.results.first { !$0.success }?.error ?? "Unknown error"
        await showErrorAndAlternatives(error: errorMessage, plan: result.plan)
    }
}
```

#### 5.2 Undo Support

Track recent actions for undo capability:

```swift
class ActionHistory {
    private var history: [(Action, ActionResult)] = []
    private let maxHistory = 10

    func record(_ action: Action, result: ActionResult) {
        history.append((action, result))
        if history.count > maxHistory {
            history.removeFirst()
        }
    }

    func canUndo(_ action: Action) -> Bool {
        // Only clipboard actions can be undone
        return action.type == .copy
    }

    func undo() async throws {
        guard let last = history.popLast(),
              canUndo(last.0) else {
            throw ActionError.cannotUndo
        }
        // Restore previous clipboard state, etc.
    }
}
```

#### 5.3 Multi-Step Workflows

Enable chaining multiple skills:

```swift
// Example: "Improve this code and commit it"
let workflow = SkillWorkflow(steps: [
    .skill("code-improvement"),
    .waitForConfirmation,
    .skill("git-commit")
])
```

---

## File Structure

```
IRIS/
├── Skills/
│   ├── SkillRegistry.swift      ✅ Implemented
│   └── SkillLoader.swift        ✅ Implemented
├── Services/
│   ├── ActionExecutor.swift     ✅ Implemented
│   ├── AppleScriptBridge.swift  ✅ Implemented
│   ├── ActionPlanner.swift      ✅ Implemented
│   └── GeminiAssistantOrchestrator.swift  ✅ Updated
└── UI/
    ├── DebugSkillBadge.swift    ✅ Implemented
    ├── EtherealFloatingOverlay.swift  ✅ Updated
    └── ExecutionConfirmationView.swift  ⏳ TODO

IRISCore/
└── Sources/Models/
    ├── Skill.swift              ✅ Implemented
    └── ProactiveSuggestion.swift  ✅ Updated
```

---

## macOS Permissions Required

| Capability | Permission | Status |
|------------|------------|--------|
| AppleScript app control | Accessibility | Already have |
| Shell commands | None | Available |
| Clipboard | None | Available |
| Screen capture | Screen Recording | Already have |

---

## Testing Checklist

### Development Testing
- [ ] Skill Detection: Verify correct skill matched for different screen contexts
- [ ] Debug Badge: Confirm badge shows in debug builds only
- [ ] Action Planning: Test action plan generation for each skill
- [ ] Execution: Test each action type (shell, AppleScript, clipboard)

### Integration Testing
- [ ] Code Improvement Flow: Screenshot code → Suggest improvement → Copy improved version
- [ ] Message Reply Flow: Screenshot chat → Draft reply → Paste into app
- [ ] Search Flow: Selected text → Auto-search → Open browser
- [ ] Bug Fix Flow: Screenshot error → Analyze → Suggest/apply fix

### Safety Testing
- [ ] Verify no destructive actions without confirmation
- [ ] Test action cancellation mid-execution
- [ ] Verify clipboard operations don't leak sensitive data
- [ ] Test AppleScript sandboxing

---

## Design Decisions

1. **Confirmation UX**: Auto-execute at high confidence (>90%). Lower confidence requires explicit "yes"/"do it".
2. **Skill Sources**: IRIS-specific definitions optimized for gaze+voice+screenshot context.
3. **Priority Capabilities**: Full AppleScript + Shell commands from day one. Clipboard/Web as baseline.
4. **Permissions**: Uses existing Accessibility permission for AppleScript.
