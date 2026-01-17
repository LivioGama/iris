# ICOI Intent-Based Layouts

IRIS automatically detects the type of request you make and adapts the UI layout accordingly.

## Intent Types and Their Layouts

### 1. **Code Improvement** (`codeImprovement`)
**Triggered by:** "improve this code", "optimize this function", "refactor this"

**Layout:**
- Hides the screenshot
- Shows side-by-side code comparison:
  - **Left**: Original code (with red tint border)
  - **Right**: Improved code (with green tint border)
- Lists key improvements at the top
- Copy button for the new code

**Visual Indicator:** Blue badge with code icon `</>`

---

### 2. **Message Reply** (`messageReply`)
**Triggered by:** "how should I reply?", "suggest a response", "what should I say back?"

**Layout:**
- Shows reply suggestions in chat bubble format (iMessage-style)
- 3 options with different tones:
  - **Purple bubble**: Empathetic/warm response
  - **Blue bubble**: Concise/direct response
  - **Green bubble**: Assertive/professional response
- Each bubble aligned to the right (like your messages)
- Copy and Use buttons below each suggestion

**Visual Indicator:** Purple badge with message icon

---

### 3. **Summarization** (`summarize`)
**Triggered by:** "summarize this", "what are the key points?", "give me an overview"

**Layout:**
- Structured summary with clear sections:
  - **Main Points**: Bullet list of key information
  - **Actions**: Who needs to do what and when
  - **Decisions**: What was decided
  - **Open Items**: Blockers or questions
- Clean, scannable format
- Export to markdown option

**Visual Indicator:** Orange badge with document icon

---

### 4. **Tone Feedback** (`toneFeedback`)
**Triggered by:** "analyze the tone", "how does this sound?", "rewrite this more professionally"

**Layout:**
- Tone analysis section showing:
  - Current tone assessment
  - Potential issues or concerns
- 3 rewritten versions:
  - **Professional**: Formal and business-appropriate
  - **Friendly**: Warm and approachable
  - **Diplomatic**: Tactful and neutral
- Copy button for each version

**Visual Indicator:** Green badge with text icon

---

### 5. **Chart Analysis** (`chartAnalysis`)
**Triggered by:** "what does this chart show?", "analyze this graph", "explain these trends"

**Layout:**
- Main trends with specific numbers
- One-sentence key insight with data
- Suggested descriptive title
- Clean, data-focused format

**Visual Indicator:** Teal badge with chart icon

---

### 6. **General** (`general`)
**Triggered by:** Any request that doesn't fit the above categories

**Layout:**
- Standard chat interface
- Screenshot visible on the left
- Conversational responses
- No special formatting

**Visual Indicator:** No badge (default mode)

---

## How It Works

1. **Voice Recognition**: You speak your request
2. **AI Classification**: Gemini 3 Flash analyzes your intent in <1 second
3. **Layout Selection**: UI automatically switches to the appropriate layout
4. **Specialized Response**: Gemini generates a response optimized for that intent
5. **Visual Feedback**: Intent badge appears showing what was detected

All responses automatically match your input language.
