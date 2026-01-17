# ICOI Implementation Plan - Interactive Context-Oriented Interface

## Executive Summary

This plan details the implementation of 5 ICOI use cases that enhance IRIS with intelligent, context-aware AI assistance triggered by blink + voice commands. The system already has the core foundation (blink detection, screen capture, AI integration, voice recognition), so this plan focuses on **enhancing prompts, adding specialized response formatting, and creating action-oriented UI elements**.

---

## Use Cases Overview

1. **Instant Message Response** - Generate empathetic message replies without typing
2. **Code Improvement** - Get better code implementations via blink + voice
3. **Meeting Summarization** - Transform meeting transcripts into structured summaries
4. **Writing Feedback** - Analyze tone and rewrite text professionally
5. **Chart Analysis** - Explain graphs and data visualizations instantly

---

## Phase 1: Core ICOI Infrastructure

### 1.1 Intent Classification System

**New Service:** `IntentClassificationService.swift` (IRISCore)

**Purpose:** Classify user voice commands into specific ICOI intents

**Implementation:**
- Create enum `ICOIIntent` with cases:
  - `.messageReply` - "respond", "reply", "answer this"
  - `.codeImprovement` - "improve", "better implementation", "refactor"
  - `.summarize` - "summarize", "résumé", "key points"
  - `.toneFeedback` - "analyze tone", "professional version", "rewrite"
  - `.chartAnalysis` - "explain this graph", "what does this show"
  - `.general` - fallback for unclassified requests

- Use keyword matching with French + English support
- Return `ICOIIntent` + confidence score (0-1)
- Trigger different prompt templates based on intent

**Integration Point:** `GeminiAssistantOrchestrator.buildPrompt()` - Add intent classification before building prompt

**Files to modify:**
- `IRISCore/Services/IntentClassificationService.swift` (new)
- `IRIS/Services/GeminiAssistantOrchestrator.swift` (integrate classifier)

---

### 1.2 Specialized Prompt Templates

**New Component:** `ICOIPromptBuilder.swift` (IRIS/Services)

**Purpose:** Generate specialized prompts optimized for each ICOI use case

**Templates:**

#### 1.2.1 Message Reply Template
```swift
func buildMessageReplyPrompt(userRequest: String, focusedElement: String?) -> String {
    """
    The user is looking at a message and said: "\(userRequest)"
    
    FOCUSED ELEMENT: \(focusedElement ?? "none detected")
    
    TASK:
    1. Identify the message content from the screenshot
    2. Generate 3 response suggestions:
       - **Empathetic**: Warm, understanding tone
       - **Concise**: Brief, to-the-point
       - **Assertive**: Clear boundaries, professional
    
    FORMAT:
    **Option 1: Empathetic**
    [response text]
    
    **Option 2: Concise**
    [response text]
    
    **Option 3: Assertive**
    [response text]
    
    Keep each response under 100 words. Match the language of the original message.
    """
}
```

#### 1.2.2 Code Improvement Template
```swift
func buildCodeImprovementPrompt(userRequest: String) -> String {
    """
    The user is looking at code and said: "\(userRequest)"
    
    TASK:
    1. Extract the code from the screenshot
    2. Provide a better implementation
    3. Explain what's improved and why
    
    FORMAT:
    ## Improved Code
    ```[language]
    [better implementation]
    ```
    
    ## What's Better
    - [improvement 1]
    - [improvement 2]
    - [improvement 3]
    
    Focus on: readability, performance, best practices, and maintainability.
    """
}
```

#### 1.2.3 Summarization Template
```swift
func buildSummarizationPrompt(userRequest: String) -> String {
    """
    The user is looking at text/transcript and said: "\(userRequest)"
    
    TASK: Create a structured summary with:
    
    ## 🎯 Main Objectives
    - [objective 1]
    - [objective 2]
    
    ## ✅ Actions Assigned
    - [who]: [what] - [deadline if mentioned]
    
    ## 📌 Decisions Made
    - [decision 1]
    - [decision 2]
    
    ## ⚠️ Blockers / Open Questions
    - [blocker 1]
    - [blocker 2]
    
    Keep it concise. Extract only what's essential.
    """
}
```

#### 1.2.4 Tone Feedback Template
```swift
func buildToneFeedbackPrompt(userRequest: String) -> String {
    """
    The user is looking at text they wrote and said: "\(userRequest)"
    
    TASK:
    1. Extract the text from the screenshot
    2. Analyze the tone (formal/informal, positive/negative, energetic/calm)
    3. Provide 3 rewritten versions:
       - **Professional**: Business-appropriate, neutral
       - **Friendly**: Warm but professional
       - **Diplomatic**: Tactful, avoids conflict
    
    FORMAT:
    ## Original Tone Analysis
    - Formality: [level]
    - Sentiment: [positive/negative/neutral]
    - Energy: [high/medium/low]
    - Potential Issues: [if any]
    
    ## Professional Version
    [rewrite]
    
    ## Friendly Version
    [rewrite]
    
    ## Diplomatic Version
    [rewrite]
    """
}
```

#### 1.2.5 Chart Analysis Template
```swift
func buildChartAnalysisPrompt(userRequest: String) -> String {
    """
    The user is looking at a chart/graph and said: "\(userRequest)"
    
    TASK: Analyze the visual data and provide:
    
    ## 📊 Main Trends
    - [trend 1]
    - [trend 2]
    
    ## 🔍 Notable Points
    - [insight 1: with specific data]
    - [insight 2: with specific data]
    
    ## 📈 Key Takeaway
    [One-sentence summary]
    
    ## 💡 Suggested Title
    "[Descriptive title for presentation]"
    
    Be specific with numbers/percentages when visible. Keep it under 200 words.
    """
}
```

**Integration Point:** `GeminiAssistantOrchestrator.sendToGemini()` - Select template based on classified intent

**Files to create:**
- `IRIS/Services/ICOIPromptBuilder.swift`

---

## Phase 2: Enhanced Response Parsing & UI

### 2.1 Structured Response Parser

**New Service:** `ICOIResponseParser.swift` (IRIS/Services)

**Purpose:** Parse Gemini's structured responses into actionable UI components

**Capabilities:**
- Detect markdown sections (`## Header`, `**Bold**`, bullet lists)
- Extract numbered options (Option 1, Option 2, etc.)
- Parse code blocks with language detection
- Identify action items with checkboxes

**Data Models:**

```swift
enum ICOIResponseElement {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case bulletList(items: [String])
    case numberedOption(number: Int, title: String, content: String)
    case codeBlock(language: String, code: String)
    case actionItem(text: String, assignee: String?, completed: Bool)
}

struct ICOIParsedResponse {
    let elements: [ICOIResponseElement]
    let hasOptions: Bool // For interactive selection
    let hasCodeBlock: Bool // For copy button
    let hasActionItems: Bool // For task tracking
}
```

**Integration Point:** `GeminiAssistantOrchestrator` - Parse response before displaying in overlay

**Files to create:**
- `IRISCore/Models/ICOIResponseElement.swift`
- `IRIS/Services/ICOIResponseParser.swift`

---

### 2.2 Enhanced Overlay UI Components

#### 2.2.1 Option Selection Buttons

**Component:** `OptionSelectionView.swift` (IRIS/UI)

**Purpose:** Display clickable numbered options for message replies, tone variants, etc.

**Design:**
```
┌────────────────────────────────────────┐
│  **Option 1: Empathetic**              │
│  "I completely understand how you..."  │
│  [📋 Copy]    [➡️ Use This]            │
└────────────────────────────────────────┘
```

**Features:**
- Numbered button grid (1-9 keyboard shortcuts)
- Copy to clipboard button
- "Use This" action (future: auto-paste integration)
- Voice command support ("use option 2", "copy option 1")

**Files to create:**
- `IRIS/UI/Components/OptionSelectionView.swift`

---

#### 2.2.2 Code Display with Copy Button

**Component:** `CodeBlockView.swift` (IRIS/UI)

**Purpose:** Display code with syntax highlighting and easy copy

**Design:**
```
┌─────────────────────────────────────────┐
│  swift                    [📋 Copy]     │
├─────────────────────────────────────────┤
│  func improvedVersion() {               │
│      // Better implementation           │
│  }                                      │
└─────────────────────────────────────────┘
```

**Features:**
- Monospace font
- Language badge
- One-click copy
- Line numbers (optional)

**Files to create:**
- `IRIS/UI/Components/CodeBlockView.swift`

---

#### 2.2.3 Structured Summary View

**Component:** `StructuredSummaryView.swift` (IRIS/UI)

**Purpose:** Display meeting summaries with collapsible sections

**Design:**
```
🎯 Main Objectives                    [▼]
  - Launch Q1 campaign
  - Hire 2 developers

✅ Actions Assigned                   [▼]
  - Alice: Design mockups (Feb 1)
  - Bob: Review code (Jan 20)

📌 Decisions Made                     [▶]
  ...
```

**Features:**
- Emoji icons for visual scanning
- Collapsible sections
- Export to markdown button

**Files to create:**
- `IRIS/UI/Components/StructuredSummaryView.swift`

---

### 2.3 Voice Command Enhancements

**Extend:** `VoiceInteractionService.swift`

**New Commands:**
- "use option [number]" → Auto-select numbered option
- "copy option [number]" → Copy specific option
- "copy code" → Copy code block
- "export summary" → Save to file
- "show more" → Expand collapsed section

**Implementation:**
- Add command pattern matching in `VoiceInteractionService`
- Emit `ICOIVoiceAction` events via delegate
- Handle in `GeminiAssistantOrchestrator`

**Files to modify:**
- `IRISMedia/Speech/VoiceInteractionService.swift`
- `IRIS/Services/GeminiAssistantOrchestrator.swift`

---

## Phase 3: Use Case-Specific Enhancements

### 3.1 Use Case 1: Instant Message Reply

**Enhancements:**
- **Detect messaging apps** (WhatsApp, iMessage, Slack, Teams) via Accessibility API
- **Extract message context** - sender name, timestamp, conversation thread
- **Tone preservation** - Match formality of original message
- **Multi-language support** - Detect language and respond accordingly

**Implementation:**
1. In `ElementDetectionService`, add messaging app detection:
   ```swift
   func isMessagingApp(_ element: DetectedElement) -> Bool {
       let messagingApps = ["WhatsApp", "Messages", "Slack", "Microsoft Teams", "Discord"]
       return messagingApps.contains(where: { element.appName.contains($0) })
   }
   ```

2. Update `buildPrompt()` to include app context:
   ```swift
   if isMessagingApp(focusedElement) {
       prompt += "\nCONTEXT: This is a \(focusedElement.appName) conversation."
   }
   ```

3. Add language detection using `NLLanguageRecognizer`

**Files to modify:**
- `IRISVision/Services/ElementDetectionService.swift`
- `IRIS/Services/GeminiAssistantOrchestrator.swift`

---

### 3.2 Use Case 2: Code Improvement

**Enhancements:**
- **Language detection** - Identify programming language from screenshot
- **Context awareness** - File path, function name from IDE
- **IDE integration** - Detect VSCode, Xcode, IntelliJ

**Implementation:**
1. Detect code editor windows:
   ```swift
   let codeEditors = ["Visual Studio Code", "Xcode", "IntelliJ IDEA", "Sublime Text"]
   ```

2. Use Vision framework's text recognition to extract:
   - File path from title bar
   - Line numbers
   - Function/class names

3. Include in prompt:
   ```swift
   if isCodeEditor(focusedElement) {
       prompt += "\nFILE: \(detectedFilePath ?? "unknown")"
       prompt += "\nLINES: \(detectedLineRange ?? "unknown")"
   }
   ```

**Files to modify:**
- `IRISVision/Services/ElementDetectionService.swift`
- `IRIS/Services/ICOIPromptBuilder.swift`

---

### 3.3 Use Case 3: Meeting Summarization

**Enhancements:**
- **Detect meeting apps** (Zoom, Teams, Google Meet)
- **Transcript extraction** - OCR for live captions
- **Time-stamped sections** - "00:15 - Discussion about X"

**Implementation:**
1. Add meeting app detection
2. For long transcripts, use OCR to extract text:
   ```swift
   let recognizedText = try await VisionService.recognizeText(from: screenshot)
   ```

3. Send transcript as text (more efficient than image for long content):
   ```swift
   if recognizedText.count > 500 {
       // Send as text instead of image
       request.addTextPart(recognizedText)
   }
   ```

**Files to modify:**
- `IRISVision/Services/VisionService.swift`
- `IRIS/Services/GeminiAssistantOrchestrator.swift`

---

### 3.4 Use Case 4: Writing Feedback

**Enhancements:**
- **Detect writing apps** (Mail, Notes, Word, Google Docs)
- **Context detection** - Email vs. note vs. document
- **Recipient analysis** - Formality based on recipient

**Implementation:**
1. Add writing app detection
2. Extract recipient info from email headers (if visible)
3. Adjust tone recommendation based on context:
   ```swift
   if detectedApp == "Mail" && hasRecipient {
       prompt += "\nRECIPIENT: \(recipientName)"
       prompt += "\nAdjust formality based on recipient context."
   }
   ```

**Files to modify:**
- `IRISVision/Services/ElementDetectionService.swift`
- `IRIS/Services/ICOIPromptBuilder.swift`

---

### 3.5 Use Case 5: Chart Analysis

**Enhancements:**
- **Chart type detection** - Bar, line, pie, scatter
- **Data extraction** - OCR for axis labels, values, legend
- **Color analysis** - Identify color-coded categories

**Implementation:**
1. Use Vision framework to detect chart elements:
   - Axis labels
   - Legend text
   - Data point values
   - Title

2. Include extracted data in prompt:
   ```swift
   prompt += "\nDETECTED CHART ELEMENTS:"
   prompt += "\n- Title: \(chartTitle)"
   prompt += "\n- X-Axis: \(xAxisLabel)"
   prompt += "\n- Y-Axis: \(yAxisLabel)"
   prompt += "\n- Legend: \(legendItems.joined(separator: ", "))"
   ```

**Files to modify:**
- `IRISVision/Services/VisionService.swift`
- `IRIS/Services/ICOIPromptBuilder.swift`

---

## Phase 4: Clipboard & Export Actions

### 4.1 Clipboard Integration

**New Service:** `ClipboardActionService.swift` (IRISMedia)

**Purpose:** Copy content to clipboard with rich formatting

**Capabilities:**
- Copy plain text
- Copy markdown (for summaries)
- Copy code (preserves formatting)
- Copy with metadata (timestamp, source)

**Implementation:**
```swift
class ClipboardActionService {
    func copyToClipboard(_ content: String, format: ClipboardFormat = .plainText) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch format {
        case .plainText:
            pasteboard.setString(content, forType: .string)
        case .markdown:
            pasteboard.setString(content, forType: .string)
            // Also set HTML representation for rich paste
        case .code:
            pasteboard.setString(content, forType: .string)
        }
    }
}

enum ClipboardFormat {
    case plainText, markdown, code
}
```

**Files to create:**
- `IRISMedia/Services/ClipboardActionService.swift`

---

### 4.2 Export to File

**Extend:** `ClipboardActionService.swift`

**Capabilities:**
- Save summary as `.md` file
- Save code as `.swift`/`.py`/etc
- Auto-name based on timestamp + context

**Implementation:**
```swift
func exportToFile(_ content: String, suggestedName: String, type: FileType) async throws {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = suggestedName
    panel.allowedContentTypes = [type.utType]
    
    if panel.runModal() == .OK, let url = panel.url {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
```

---

## Phase 5: Testing & Validation

### 5.1 Unit Tests

**Test Coverage:**
- `IntentClassificationService` - All keywords, edge cases
- `ICOIPromptBuilder` - Template generation for all intents
- `ICOIResponseParser` - Parsing various markdown formats
- `ClipboardActionService` - Copy operations

**Files to create:**
- `IRISTests/IntentClassificationServiceTests.swift`
- `IRISTests/ICOIPromptBuilderTests.swift`
- `IRISTests/ICOIResponseParserTests.swift`

---

### 5.2 Integration Tests

**Scenarios to test:**
1. **Message Reply Flow:**
   - Open WhatsApp
   - Blink on message
   - Say "respond calmly with empathy"
   - Verify 3 options displayed
   - Voice command "use option 2"
   - Verify clipboard has content

2. **Code Improvement Flow:**
   - Open VSCode with code visible
   - Blink on code
   - Say "give me a better implementation"
   - Verify improved code + explanation displayed
   - Click copy button
   - Paste in editor

3. **Meeting Summary Flow:**
   - Open Zoom transcript
   - Blink on transcript
   - Say "summarize this"
   - Verify structured summary with sections
   - Click export
   - Verify .md file saved

4. **Tone Feedback Flow:**
   - Open Mail with draft
   - Blink on email body
   - Say "analyze tone and make it professional"
   - Verify tone analysis + 3 rewrites
   - Select option
   - Verify copied

5. **Chart Analysis Flow:**
   - Open PDF with graph
   - Blink on chart
   - Say "explain this graph"
   - Verify trends + key points
   - Copy suggested title

**Files to create:**
- `IRISTests/ICOIIntegrationTests.swift`

---

## Critical Files to Modify

### Core Services
1. `IRIS/Services/GeminiAssistantOrchestrator.swift`
   - Integrate `IntentClassificationService`
   - Use `ICOIPromptBuilder` for specialized prompts
   - Parse responses with `ICOIResponseParser`
   - Handle voice actions

2. `IRISCore/Services/IntentClassificationService.swift` *(new)*
   - Intent classification logic

3. `IRIS/Services/ICOIPromptBuilder.swift` *(new)*
   - All prompt templates

4. `IRIS/Services/ICOIResponseParser.swift` *(new)*
   - Response parsing logic

### UI Components
5. `IRIS/UI/GeminiResponseOverlay.swift`
   - Add structured UI components based on parsed response
   - Show option buttons for message replies
   - Show code blocks with copy button
   - Show structured summaries

6. `IRIS/UI/Components/OptionSelectionView.swift` *(new)*
   - Interactive option selection

7. `IRIS/UI/Components/CodeBlockView.swift` *(new)*
   - Code display with copy

8. `IRIS/UI/Components/StructuredSummaryView.swift` *(new)*
   - Summary sections with icons

### Detection Services
9. `IRISVision/Services/ElementDetectionService.swift`
   - Add app type detection (messaging, code editor, meeting, writing)
   - Extract contextual metadata

10. `IRISVision/Services/VisionService.swift`
    - Add chart element detection
    - Extract text from long content

### Media Services
11. `IRISMedia/Services/ClipboardActionService.swift` *(new)*
    - Clipboard + export functionality

12. `IRISMedia/Speech/VoiceInteractionService.swift`
    - Add ICOI voice commands (use option X, copy code, etc.)

---

## Data Models to Create

1. `IRISCore/Models/ICOIIntent.swift`
   ```swift
   enum ICOIIntent {
       case messageReply, codeImprovement, summarize, toneFeedback, chartAnalysis, general
   }
   ```

2. `IRISCore/Models/ICOIResponseElement.swift`
   ```swift
   enum ICOIResponseElement {
       case heading, paragraph, bulletList, numberedOption, codeBlock, actionItem
   }
   ```

3. `IRISCore/Models/ICOIParsedResponse.swift`
   ```swift
   struct ICOIParsedResponse {
       let elements: [ICOIResponseElement]
       let hasOptions: Bool
       let hasCodeBlock: Bool
       let hasActionItems: Bool
   }
   ```

---

## Implementation Order

### Iteration 1: Core Infrastructure (Days 1-3)
- [ ] Create `IntentClassificationService`
- [ ] Create `ICOIPromptBuilder` with all 5 templates
- [ ] Create `ICOIResponseParser`
- [ ] Integrate intent classification in `GeminiAssistantOrchestrator`
- [ ] Test intent detection with voice commands

### Iteration 2: UI Components (Days 4-6)
- [ ] Create `OptionSelectionView`
- [ ] Create `CodeBlockView`
- [ ] Create `StructuredSummaryView`
- [ ] Update `GeminiResponseOverlay` to use parsed response elements
- [ ] Add clipboard service

### Iteration 3: Context Detection (Days 7-9)
- [ ] Add messaging app detection
- [ ] Add code editor detection
- [ ] Add meeting app detection
- [ ] Add writing app detection
- [ ] Add chart element extraction

### Iteration 4: Voice Commands & Actions (Days 10-12)
- [ ] Extend voice commands for option selection
- [ ] Add copy/export actions
- [ ] Integrate clipboard service
- [ ] Add export to file

### Iteration 5: Testing & Refinement (Days 13-15)
- [ ] Write unit tests
- [ ] Run integration tests for all 5 use cases
- [ ] Fix bugs and edge cases
- [ ] Performance optimization
- [ ] Documentation

---

## Success Metrics

**Functional:**
- ✅ All 5 use cases work end-to-end
- ✅ Voice commands trigger correct intents (>90% accuracy)
- ✅ Response parsing handles all formats
- ✅ Copy/export actions work reliably

**Performance:**
- ⚡ Intent classification < 50ms
- ⚡ Response parsing < 100ms
- ⚡ Total blink-to-response < 3 seconds

**UX:**
- 😊 Options are clearly labeled and clickable
- 😊 Code blocks are readable and copyable
- 😊 Summaries are scannable with visual hierarchy
- 😊 Voice commands feel natural

---

## Verification Plan

### End-to-End Testing Workflow

**Test 1: Message Reply**
1. Open WhatsApp with a tense message visible
2. Blink on message
3. Say "respond calmly with empathy"
4. **Expected:** 3 numbered options appear
5. Say "use option 2"
6. **Expected:** Option 2 copied to clipboard
7. Paste in WhatsApp → verify content matches

**Test 2: Code Improvement**
1. Open VSCode with a function visible
2. Blink on code
3. Say "give me a better implementation"
4. **Expected:** Improved code + explanation displayed
5. Click copy button
6. **Expected:** Code copied to clipboard
7. Paste in VSCode → verify syntax is valid

**Test 3: Meeting Summarization**
1. Open Zoom with transcript visible
2. Blink on transcript
3. Say "make a summary"
4. **Expected:** Structured summary with 🎯✅📌⚠️ sections
5. Click export button
6. **Expected:** Save dialog opens
7. Save as `meeting-summary.md` → verify file contents

**Test 4: Writing Feedback**
1. Open Mail with draft email visible
2. Blink on email body
3. Say "analyze my tone and make it professional"
4. **Expected:** Tone analysis + 3 rewrite options
5. Say "copy option 1"
6. **Expected:** Professional version copied
7. Paste in email → verify tone is appropriate

**Test 5: Chart Analysis**
1. Open PDF with bar chart visible
2. Blink on chart
3. Say "explain this graph in simple terms"
4. **Expected:** Trends, notable points, takeaway, suggested title
5. Verify numbers mentioned match chart
6. Copy suggested title → verify clipboard

---

## Risk Mitigation

**Risk 1: Intent misclassification**
- Mitigation: Fallback to general prompt if confidence < 0.7
- Log misclassifications for iterative improvement

**Risk 2: Response parsing fails**
- Mitigation: Graceful degradation to plain text display
- Show error message with option to view raw response

**Risk 3: Voice commands not recognized**
- Mitigation: Show available commands in overlay footer
- Support both voice + click interactions

**Risk 4: Performance degradation**
- Mitigation: Profile critical paths
- Cache prompt templates
- Optimize parsing with early exit strategies

---

## Future Enhancements (Post-MVP)

1. **Auto-paste** - Directly inject text into focused app
2. **Action history** - Review past responses
3. **Custom templates** - User-defined prompt templates
4. **Multi-turn refinement** - "Make it shorter", "Add more detail"
5. **Context learning** - Personalize based on usage patterns
6. **Collaborative features** - Share summaries with team
7. **Analytics** - Track most-used intents

---

## Conclusion

This plan leverages IRIS's existing architecture to add powerful ICOI capabilities with minimal disruption. The modular approach allows incremental implementation and testing. Each use case builds on shared infrastructure (intent classification, prompt building, response parsing) while adding specialized enhancements.

**Estimated effort:** 15 days for full implementation + testing
**Complexity:** Medium (mostly integration, not new architecture)
**Impact:** High (transforms IRIS from passive assistant to proactive collaborator)
