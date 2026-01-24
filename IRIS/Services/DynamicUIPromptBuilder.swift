import Foundation
import IRISCore

/// Builds prompts for Gemini to generate dynamic UI schemas
public class DynamicUIPromptBuilder {

    public init() {}

    /// Build the system prompt that instructs Gemini to output UI schemas
    public func buildSystemPrompt() -> String {
        return """
        You are IRIS, an intelligent AI assistant that analyzes screenshots and user requests to generate custom user interfaces.

        Your task is to:
        1. Analyze the screenshot provided
        2. Understand the user's request/question
        3. Generate a response with BOTH:
           - A helpful text response
           - A JSON UI schema that best presents the information

        ## RESPONSE FORMAT

        You MUST respond in this exact format:

        ```response
        [Your helpful text response here - be concise and direct]
        ```

        ```ui-schema
        {
          "layout": { ... },
          "theme": { ... },
          "components": [ ... ],
          "screenshotConfig": { ... }
        }
        ```

        ## UI SCHEMA SPECIFICATION

        ### Layout Options
        ```json
        {
          "direction": "vertical" | "horizontal" | "grid" | "splitHorizontal" | "splitVertical",
          "spacing": "xxs" | "xs" | "sm" | "md" | "lg" | "xl" | "xxl",
          "maxWidth": 700,  // number or null for full width
          "padding": "lg",
          "alignment": "leading" | "center" | "trailing"
        }
        ```

        ### Theme Options
        ```json
        {
          "accentColor": "#0066FF",  // hex color
          "secondaryColor": "#00D4FF",  // optional, for gradients
          "background": "dark" | "darker" | "warm" | "cool" | "glass",
          "mood": "neutral" | "analytical" | "friendly" | "urgent" | "success" | "creative",
          "icon": "💻",  // optional emoji
          "title": "Code Review"  // optional title
        }
        ```

        ### Screenshot Config (optional)
        ```json
        {
          "visible": true,
          "position": "top" | "left" | "right" | "background" | "hidden",
          "size": "small" | "medium" | "large" | "fullWidth",
          "opacity": 0.8,
          "cornerRadius": 12,
          "showBorder": true
        }
        ```

        ### Available Components

        #### Text Components
        - **heading**: `{"text": "Title", "level": 1|2|3, "icon": "🔍"}`
        - **paragraph**: `{"text": "Content", "style": "body"|"caption"|"emphasized"|"muted"|"highlight"}`
        - **label**: `{"text": "Label", "icon": "📌", "color": "#FF0000"}`

        #### List Components
        - **bulletList**: `{"items": ["Item 1", "Item 2"], "bulletStyle": "dot"|"dash"|"arrow"|"check"|"star"}`
        - **numberedList**: `{"items": ["First", "Second"], "startFrom": 1}`
        - **checklist**: `{"items": [{"text": "Task", "checked": false, "assignee": "John"}]}`

        #### Interactive Components
        - **button**: `{"label": "Click", "action": {"type": "copy", "payload": "text"}, "style": "primary"|"secondary"|"ghost"|"destructive", "icon": "doc.on.doc"}`
        - **buttonGroup**: `{"buttons": [...], "layout": "horizontal"|"vertical"}`
        - **optionCard**: `{"id": "opt1", "title": "Option 1", "subtitle": "Recommended", "content": "Description", "icon": "✨"}`
        - **optionCards**: `{"cards": [...], "selectable": true, "layout": "vertical"}`
        - **tabs**: `{"tabs": [{"label": "Tab 1", "icon": "star", "content": [...]}], "selectedIndex": 0}`

        #### Content Components
        - **codeBlock**: `{"code": "const x = 1;", "language": "javascript", "showLineNumbers": false, "copyable": true}`
        - **codeComparison**: `{"beforeCode": "...", "afterCode": "...", "language": "python", "improvements": ["Better naming", "More efficient"]}`
        - **quote**: `{"text": "Quote text", "author": "Author", "style": "standard"|"highlight"|"warning"}`
        - **callout**: `{"type": "info"|"success"|"warning"|"error"|"tip", "title": "Note", "message": "Important info"}`
        - **divider**: `{"style": "line"|"dashed"|"gradient"|"space", "label": "Section"}`

        #### Data Components
        - **keyValue**: `{"key": "Status", "value": "Active", "icon": "✓", "valueColor": "#00FF00"}`
        - **keyValueList**: `{"items": [...], "layout": "vertical"}`
        - **progressBar**: `{"value": 0.75, "label": "Progress", "showPercentage": true, "color": "#00FF00"}`
        - **metric**: `{"label": "Users", "value": "1,234", "trend": "up"|"down"|"neutral", "trendValue": "+12%", "icon": "👥"}`
        - **metricsRow**: `{"metrics": [...]}`

        #### Layout Components
        - **stack**: `{"direction": "vertical", "spacing": "md", "alignment": "leading", "children": [...]}`
        - **card**: `{"title": "Card Title", "subtitle": "Optional", "content": [...], "style": "flat"|"elevated"|"outlined"|"glass"}`
        - **collapsible**: `{"title": "Section", "icon": "📁", "isExpanded": true, "content": [...]}`
        - **spacer**: `{"size": "md"}`

        #### Special Components
        - **image**: `{"source": {"screenshot": true} | {"systemIcon": "star.fill"}, "size": "small"|"medium"|"large"|"full"}`
        - **badge**: `{"text": "New", "style": "default"|"success"|"warning"|"error"|"info", "icon": "🔥"}`
        - **chip**: `{"text": "Tag", "icon": "🏷", "selected": false}`
        - **chips**: `{"chips": [...], "selectable": true, "multiSelect": false}`

        ### Action Types
        - `copy`: Copy payload to clipboard
        - `speak`: Text-to-speech
        - `select`: Select an option
        - `dismiss`: Close overlay
        - `expand`: Toggle expand/collapse
        - `custom`: Custom action identifier

        ## GUIDELINES

        1. **Match UI to Context**:
           - Code-related → use codeBlock, codeComparison, analytical mood
           - Messages/emails → use optionCards with different tones, friendly mood
           - Data/charts → use metrics, keyValue, progressBar, analytical mood
           - Errors/warnings → use callouts, urgent mood
           - Creative tasks → use cards, chips, creative mood

        2. **Be Selective**: Don't use every component. Choose what best presents the information.

        3. **Theme Appropriately**:
           - Code: `#0066FF` (blue), darker background, analytical
           - Messages: `#9333EA` (purple), warm background, friendly
           - Data: `#06B6D4` (cyan), cool background, analytical
           - Errors: `#EF4444` (red), dark background, urgent
           - Success: `#10B981` (green), dark background, success

        4. **Screenshot Usage**:
           - Hide if not relevant to response
           - Show small/top if referencing it
           - Show large/left for detailed analysis

        5. **Keep It Focused**: Maximum 5-8 components per response. Quality over quantity.

        ## EXAMPLES

        ### Example 1: Code Improvement Request
        User shows code and asks "improve this"

        ```response
        I've improved your code with better variable naming and error handling.
        ```

        ```ui-schema
        {
          "layout": {"direction": "vertical", "spacing": "lg", "maxWidth": 900, "padding": "lg", "alignment": "leading"},
          "theme": {"accentColor": "#0066FF", "secondaryColor": "#00D4FF", "background": "darker", "mood": "analytical", "icon": "💻", "title": "Code Improvement"},
          "components": [
            {"codeComparison": {"beforeCode": "function f(x) { return x*2 }", "afterCode": "function doubleValue(number) {\\n  if (typeof number !== 'number') {\\n    throw new Error('Expected number');\\n  }\\n  return number * 2;\\n}", "language": "javascript", "improvements": ["Descriptive function name", "Input validation added", "Clear error message"]}}
          ],
          "screenshotConfig": {"visible": false, "position": "hidden", "size": "small", "opacity": 0.8}
        }
        ```

        ### Example 2: Email Reply Suggestions
        User shows an email and asks "help me reply"

        ```response
        Here are three reply options based on the tone you might want:
        ```

        ```ui-schema
        {
          "layout": {"direction": "vertical", "spacing": "md", "maxWidth": 700, "padding": "lg", "alignment": "leading"},
          "theme": {"accentColor": "#9333EA", "secondaryColor": "#EC4899", "background": "warm", "mood": "friendly", "icon": "💬", "title": "Reply Options"},
          "components": [
            {"optionCards": {"cards": [
              {"id": "formal", "title": "Professional", "icon": "💼", "content": "Thank you for reaching out. I've reviewed your proposal and would like to schedule a call to discuss the details further."},
              {"id": "friendly", "title": "Friendly", "icon": "��", "content": "Hey! Thanks for sending this over - it looks great! Let's chat soon about next steps."},
              {"id": "direct", "title": "Direct", "icon": "🎯", "content": "Got it. I'm available Tuesday at 2pm to discuss. Let me know if that works."}
            ], "selectable": true, "layout": "vertical"}}
          ],
          "screenshotConfig": {"visible": true, "position": "top", "size": "small", "opacity": 0.5}
        }
        ```

        ### Example 3: Chart Analysis
        User shows a chart and asks "what does this show"

        ```response
        This chart shows quarterly revenue growth with a strong upward trend in Q3.
        ```

        ```ui-schema
        {
          "layout": {"direction": "splitHorizontal", "spacing": "lg", "maxWidth": 1000, "padding": "lg", "alignment": "leading"},
          "theme": {"accentColor": "#06B6D4", "secondaryColor": "#0EA5E9", "background": "cool", "mood": "analytical", "icon": "📊", "title": "Chart Analysis"},
          "components": [
            {"stack": {"direction": "vertical", "spacing": "md", "alignment": "leading", "children": [
              {"image": {"source": {"screenshot": true}, "size": "large"}}
            ]}},
            {"stack": {"direction": "vertical", "spacing": "md", "alignment": "leading", "children": [
              {"heading": {"text": "Key Insights", "level": 2, "icon": "💡"}},
              {"metricsRow": {"metrics": [
                {"label": "Peak", "value": "$4.2M", "trend": "up", "trendValue": "+23%"},
                {"label": "Growth", "value": "18%", "trend": "up", "trendValue": "QoQ"}
              ]}},
              {"bulletList": {"items": ["Q3 shows strongest performance", "Consistent upward trend since Q1", "Revenue doubled year-over-year"], "bulletStyle": "arrow"}}
            ]}}
          ],
          "screenshotConfig": {"visible": false, "position": "hidden", "size": "small", "opacity": 1}
        }
        ```

        Remember: Always output BOTH the response text AND the ui-schema. The UI should enhance, not replace, your text response.
        """
    }

    /// Build a user prompt that includes the request
    public func buildUserPrompt(userRequest: String) -> String {
        return """
        User request: \(userRequest)

        Analyze the screenshot and respond with both a helpful text answer and an appropriate UI schema.
        """
    }
}

// MARK: - Schema Extraction

public class DynamicUIResponseParser {

    public init() {}

    /// Parse a Gemini response that contains both text and UI schema
    public func parse(response: String) -> (text: String, schema: DynamicUISchema?) {
        // Extract text response
        let textPattern = "```response\\s*([\\s\\S]*?)\\s*```"
        let text: String
        if let textRegex = try? NSRegularExpression(pattern: textPattern),
           let textMatch = textRegex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let textRange = Range(textMatch.range(at: 1), in: response) {
            text = String(response[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Fallback: use everything before ui-schema as text
            if let schemaStart = response.range(of: "```ui-schema") {
                text = String(response[..<schemaStart.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                text = response.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Extract UI schema
        let schemaPattern = "```ui-schema\\s*([\\s\\S]*?)\\s*```"
        var schema: DynamicUISchema? = nil

        try? "🔍 Parsing response for UI schema...\n".appendLine(to: "/tmp/iris_ui.log")
        try? "🔍 Response contains 'ui-schema': \(response.contains("ui-schema"))\n".appendLine(to: "/tmp/iris_ui.log")
        try? "🔍 Response preview: \(String(response.prefix(500)))...\n".appendLine(to: "/tmp/iris_ui.log")

        if let schemaRegex = try? NSRegularExpression(pattern: schemaPattern),
           let schemaMatch = schemaRegex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let schemaRange = Range(schemaMatch.range(at: 1), in: response) {
            let jsonString = String(response[schemaRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            try? "🔍 Found JSON schema block, length: \(jsonString.count)\n".appendLine(to: "/tmp/iris_ui.log")
            try? "🔍 JSON preview: \(String(jsonString.prefix(500)))...\n".appendLine(to: "/tmp/iris_ui.log")

            do {
                schema = try parseUISchema(json: jsonString)
                try? "✅ Successfully parsed UI schema!\n".appendLine(to: "/tmp/iris_ui.log")
            } catch {
                try? "❌ Failed to parse UI schema: \(error)\n".appendLine(to: "/tmp/iris_ui.log")
                try? "❌ JSON that failed: \(jsonString)\n".appendLine(to: "/tmp/iris_ui.log")
            }
        } else {
            try? "⚠️ No ui-schema block found in response\n".appendLine(to: "/tmp/iris_ui.log")
        }

        return (text, schema)
    }

    /// Parse JSON string into DynamicUISchema
    private func parseUISchema(json: String) throws -> DynamicUISchema {
        guard let data = json.data(using: .utf8) else {
            throw DynamicUIParseError.invalidJSON
        }

        // Custom decoding to handle the component wrapper format
        let decoder = JSONDecoder()
        let rawSchema = try decoder.decode(RawUISchema.self, from: data)

        return DynamicUISchema(
            layout: rawSchema.layout,
            theme: rawSchema.theme,
            components: rawSchema.components.compactMap { parseComponent($0) },
            screenshotConfig: rawSchema.screenshotConfig,
            actions: nil
        )
    }

    /// Parse a raw component dictionary into a UIComponent
    private func parseComponent(_ raw: RawComponent) -> UIComponent? {
        // Each raw component has exactly one key indicating its type
        if let heading = raw.heading {
            return .heading(heading)
        }
        if let paragraph = raw.paragraph {
            return .paragraph(paragraph)
        }
        if let label = raw.label {
            return .label(label)
        }
        if let bulletList = raw.bulletList {
            return .bulletList(bulletList)
        }
        if let numberedList = raw.numberedList {
            return .numberedList(numberedList)
        }
        if let checklist = raw.checklist {
            return .checklist(checklist)
        }
        if let button = raw.button {
            return .button(button)
        }
        if let buttonGroup = raw.buttonGroup {
            return .buttonGroup(buttonGroup)
        }
        if let optionCard = raw.optionCard {
            return .optionCard(optionCard)
        }
        if let optionCards = raw.optionCards {
            return .optionCards(optionCards)
        }
        if let toggle = raw.toggle {
            return .toggle(toggle)
        }
        if let tabs = raw.tabs {
            // Parse nested components in tabs
            let parsedTabs = tabs.tabs.map { tab in
                TabItem(
                    label: tab.label,
                    icon: tab.icon,
                    content: tab.content.compactMap { parseComponent($0) }
                )
            }
            return .tabs(TabsComponent(tabs: parsedTabs, selectedIndex: tabs.selectedIndex))
        }
        if let codeBlock = raw.codeBlock {
            return .codeBlock(codeBlock)
        }
        if let codeComparison = raw.codeComparison {
            return .codeComparison(codeComparison)
        }
        if let quote = raw.quote {
            return .quote(quote)
        }
        if let callout = raw.callout {
            return .callout(callout)
        }
        if let divider = raw.divider {
            return .divider(divider)
        }
        if let keyValue = raw.keyValue {
            return .keyValue(keyValue)
        }
        if let keyValueList = raw.keyValueList {
            return .keyValueList(keyValueList)
        }
        if let progressBar = raw.progressBar {
            return .progressBar(progressBar)
        }
        if let metric = raw.metric {
            return .metric(metric)
        }
        if let metricsRow = raw.metricsRow {
            return .metricsRow(metricsRow)
        }
        if let stack = raw.stack {
            // Parse nested components in stack
            let children = stack.children.compactMap { parseComponent($0) }
            return .stack(StackComponent(
                direction: stack.direction,
                spacing: stack.spacing,
                alignment: stack.alignment,
                children: children
            ))
        }
        if let card = raw.card {
            // Parse nested components in card
            let content = card.content.compactMap { parseComponent($0) }
            return .card(CardComponent(
                title: card.title,
                subtitle: card.subtitle,
                content: content,
                style: card.style,
                action: card.action
            ))
        }
        if let collapsible = raw.collapsible {
            // Parse nested components in collapsible
            let content = collapsible.content.compactMap { parseComponent($0) }
            return .collapsible(CollapsibleComponent(
                title: collapsible.title,
                icon: collapsible.icon,
                isExpanded: collapsible.isExpanded,
                content: content
            ))
        }
        if let spacer = raw.spacer {
            return .spacer(spacer)
        }
        if let image = raw.image {
            return .image(image)
        }
        if let badge = raw.badge {
            return .badge(badge)
        }
        if let chip = raw.chip {
            return .chip(chip)
        }
        if let chips = raw.chips {
            return .chips(chips)
        }

        return nil
    }
}

// MARK: - Raw Schema Types for Decoding

/// Raw schema structure for initial JSON decoding
private struct RawUISchema: Codable {
    let layout: UILayout
    let theme: UITheme
    let components: [RawComponent]
    let screenshotConfig: ScreenshotDisplayConfig?
}

/// Raw component wrapper that can hold any component type
private struct RawComponent: Codable {
    var heading: HeadingComponent?
    var paragraph: ParagraphComponent?
    var label: LabelComponent?
    var bulletList: BulletListComponent?
    var numberedList: NumberedListComponent?
    var checklist: ChecklistComponent?
    var button: ButtonComponent?
    var buttonGroup: ButtonGroupComponent?
    var optionCard: OptionCardComponent?
    var optionCards: OptionCardsComponent?
    var toggle: ToggleComponent?
    var tabs: RawTabsComponent?
    var codeBlock: CodeBlockComponent?
    var codeComparison: CodeComparisonComponent?
    var quote: QuoteComponent?
    var callout: CalloutComponent?
    var divider: DividerComponent?
    var keyValue: KeyValueComponent?
    var keyValueList: KeyValueListComponent?
    var progressBar: ProgressBarComponent?
    var metric: MetricComponent?
    var metricsRow: MetricsRowComponent?
    var stack: RawStackComponent?
    var card: RawCardComponent?
    var collapsible: RawCollapsibleComponent?
    var spacer: SpacerComponent?
    var image: ImageComponent?
    var badge: BadgeComponent?
    var chip: ChipComponent?
    var chips: ChipsComponent?
}

/// Raw tabs with nested raw components
private struct RawTabsComponent: Codable {
    var tabs: [RawTabItem]
    var selectedIndex: Int
}

private struct RawTabItem: Codable {
    let label: String
    let icon: String?
    var content: [RawComponent]
}

/// Raw stack with nested raw components
private struct RawStackComponent: Codable {
    let direction: LayoutDirection
    let spacing: SpacingSize
    let alignment: LayoutAlignment
    var children: [RawComponent]
}

/// Raw card with nested raw components
private struct RawCardComponent: Codable {
    let title: String?
    let subtitle: String?
    var content: [RawComponent]
    let style: CardStyle
    let action: UIAction?
}

/// Raw collapsible with nested raw components
private struct RawCollapsibleComponent: Codable {
    let title: String
    let icon: String?
    let isExpanded: Bool
    var content: [RawComponent]
}

// MARK: - Extended Parsing Support

extension DynamicUIResponseParser {
    /// Convenience method to parse and extract just the schema
    public func extractSchema(from response: String) -> DynamicUISchema? {
        return parse(response: response).schema
    }

    /// Convenience method to parse and extract just the text
    public func extractText(from response: String) -> String {
        return parse(response: response).text
    }
}
