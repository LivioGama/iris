import Foundation

// MARK: - Dynamic UI Schema
// This schema allows the AI to describe arbitrary UIs that will be rendered natively in SwiftUI

/// Root schema for a dynamic UI response
public struct DynamicUISchema: Codable, Equatable {
    /// Layout configuration for the overall UI
    public let layout: UILayout

    /// Visual theme/mood of the UI
    public let theme: UITheme

    /// The components to render
    public let components: [UIComponent]

    /// Optional screenshot treatment
    public let screenshotConfig: ScreenshotDisplayConfig?

    /// Optional actions available at the UI level
    public let actions: [UIAction]?

    public init(
        layout: UILayout,
        theme: UITheme,
        components: [UIComponent],
        screenshotConfig: ScreenshotDisplayConfig? = nil,
        actions: [UIAction]? = nil
    ) {
        self.layout = layout
        self.theme = theme
        self.components = components
        self.screenshotConfig = screenshotConfig
        self.actions = actions
    }
}

// MARK: - Layout Configuration

/// Defines how components are arranged
public struct UILayout: Codable, Equatable {
    /// Primary layout direction
    public let direction: LayoutDirection

    /// Spacing between components
    public let spacing: SpacingSize

    /// Maximum width constraint (nil = full width)
    public let maxWidth: CGFloat?

    /// Padding around the content
    public let padding: SpacingSize

    /// Alignment within the container
    public let alignment: LayoutAlignment

    public init(
        direction: LayoutDirection = .vertical,
        spacing: SpacingSize = .md,
        maxWidth: CGFloat? = 700,
        padding: SpacingSize = .lg,
        alignment: LayoutAlignment = .leading
    ) {
        self.direction = direction
        self.spacing = spacing
        self.maxWidth = maxWidth
        self.padding = padding
        self.alignment = alignment
    }
}

public enum LayoutDirection: String, Codable, Equatable {
    case vertical
    case horizontal
    case grid
    case splitHorizontal  // Two columns
    case splitVertical    // Two rows
}

public enum SpacingSize: String, Codable, Equatable {
    case xxs, xs, sm, md, lg, xl, xxl

    public var value: CGFloat {
        switch self {
        case .xxs: return 2
        case .xs: return 4
        case .sm: return 8
        case .md: return 16
        case .lg: return 24
        case .xl: return 32
        case .xxl: return 48
        }
    }
}

public enum LayoutAlignment: String, Codable, Equatable {
    case leading, center, trailing
}

// MARK: - Theme Configuration

/// Visual theme for the UI
public struct UITheme: Codable, Equatable {
    /// Primary accent color (hex)
    public let accentColor: String

    /// Secondary accent color for gradients (hex)
    public let secondaryColor: String?

    /// Background style
    public let background: BackgroundStyle

    /// Overall mood/feeling
    public let mood: UIMood

    /// Icon/emoji for the mode
    public let icon: String?

    /// Display title
    public let title: String?

    public init(
        accentColor: String,
        secondaryColor: String? = nil,
        background: BackgroundStyle = .dark,
        mood: UIMood = .neutral,
        icon: String? = nil,
        title: String? = nil
    ) {
        self.accentColor = accentColor
        self.secondaryColor = secondaryColor
        self.background = background
        self.mood = mood
        self.icon = icon
        self.title = title
    }
}

public enum BackgroundStyle: String, Codable, Equatable {
    case dark       // Standard dark background
    case darker     // Code-editor style
    case warm       // Slightly warmer tone
    case cool       // Slightly cooler tone
    case glass      // Glassmorphic
}

public enum UIMood: String, Codable, Equatable {
    case neutral
    case analytical   // For code, data
    case friendly     // For messages, help
    case urgent       // For errors, warnings
    case success      // For completions, confirmations
    case creative     // For suggestions, ideas
}

// MARK: - Screenshot Configuration

public struct ScreenshotDisplayConfig: Codable, Equatable {
    public let visible: Bool
    public let position: ScreenshotPosition
    public let size: ScreenshotSize
    public let opacity: Double
    public let cornerRadius: CGFloat?
    public let showBorder: Bool

    public init(
        visible: Bool = true,
        position: ScreenshotPosition = .top,
        size: ScreenshotSize = .medium,
        opacity: Double = 0.8,
        cornerRadius: CGFloat? = 12,
        showBorder: Bool = true
    ) {
        self.visible = visible
        self.position = position
        self.size = size
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.showBorder = showBorder
    }
}

public enum ScreenshotPosition: String, Codable, Equatable {
    case top, left, right, background, hidden
}

public enum ScreenshotSize: String, Codable, Equatable {
    case small, medium, large, fullWidth

    public var maxDimension: CGFloat {
        switch self {
        case .small: return 200
        case .medium: return 350
        case .large: return 500
        case .fullWidth: return .infinity
        }
    }
}

// MARK: - UI Components (The Heart of Dynamic UI)

/// A component that can be rendered in the dynamic UI
public enum UIComponent: Codable, Equatable {
    // Text components
    case heading(HeadingComponent)
    case paragraph(ParagraphComponent)
    case label(LabelComponent)

    // List components
    case bulletList(BulletListComponent)
    case numberedList(NumberedListComponent)
    case checklist(ChecklistComponent)

    // Interactive components
    case button(ButtonComponent)
    case buttonGroup(ButtonGroupComponent)
    case optionCard(OptionCardComponent)
    case optionCards(OptionCardsComponent)
    case toggle(ToggleComponent)
    case tabs(TabsComponent)

    // Content components
    case codeBlock(CodeBlockComponent)
    case codeComparison(CodeComparisonComponent)
    case quote(QuoteComponent)
    case callout(CalloutComponent)
    case divider(DividerComponent)

    // Data components
    case keyValue(KeyValueComponent)
    case keyValueList(KeyValueListComponent)
    case progressBar(ProgressBarComponent)
    case metric(MetricComponent)
    case metricsRow(MetricsRowComponent)

    // Layout components
    case stack(StackComponent)
    case card(CardComponent)
    case collapsible(CollapsibleComponent)
    case spacer(SpacerComponent)

    // Special components
    case image(ImageComponent)
    case badge(BadgeComponent)
    case chip(ChipComponent)
    case chips(ChipsComponent)
}

// MARK: - Text Components

public struct HeadingComponent: Codable, Equatable {
    public let text: String
    public let level: Int  // 1, 2, or 3
    public let icon: String?

    public init(text: String, level: Int = 1, icon: String? = nil) {
        self.text = text
        self.level = level
        self.icon = icon
    }
}

public struct ParagraphComponent: Codable, Equatable {
    public let text: String
    public let style: TextStyle

    public init(text: String, style: TextStyle = .body) {
        self.text = text
        self.style = style
    }
}

public struct LabelComponent: Codable, Equatable {
    public let text: String
    public let icon: String?
    public let color: String?  // hex color

    public init(text: String, icon: String? = nil, color: String? = nil) {
        self.text = text
        self.icon = icon
        self.color = color
    }
}

public enum TextStyle: String, Codable, Equatable {
    case body, caption, emphasized, muted, highlight
}

// MARK: - List Components

public struct BulletListComponent: Codable, Equatable {
    public let items: [String]
    public let bulletStyle: BulletStyle

    public init(items: [String], bulletStyle: BulletStyle = .dot) {
        self.items = items
        self.bulletStyle = bulletStyle
    }
}

public enum BulletStyle: String, Codable, Equatable {
    case dot, dash, arrow, check, star
}

public struct NumberedListComponent: Codable, Equatable {
    public let items: [String]
    public let startFrom: Int

    public init(items: [String], startFrom: Int = 1) {
        self.items = items
        self.startFrom = startFrom
    }
}

public struct ChecklistComponent: Codable, Equatable {
    public let items: [ChecklistItem]

    public init(items: [ChecklistItem]) {
        self.items = items
    }
}

public struct ChecklistItem: Codable, Equatable {
    public let text: String
    public let checked: Bool
    public let assignee: String?

    public init(text: String, checked: Bool = false, assignee: String? = nil) {
        self.text = text
        self.checked = checked
        self.assignee = assignee
    }
}

// MARK: - Interactive Components

public struct ButtonComponent: Codable, Equatable {
    public let label: String
    public let action: UIAction
    public let style: ButtonStyle
    public let icon: String?

    public init(label: String, action: UIAction, style: ButtonStyle = .secondary, icon: String? = nil) {
        self.label = label
        self.action = action
        self.style = style
        self.icon = icon
    }
}

public enum ButtonStyle: String, Codable, Equatable {
    case primary, secondary, ghost, destructive
}

public struct ButtonGroupComponent: Codable, Equatable {
    public let buttons: [ButtonComponent]
    public let layout: LayoutDirection

    public init(buttons: [ButtonComponent], layout: LayoutDirection = .horizontal) {
        self.buttons = buttons
        self.layout = layout
    }
}

public struct OptionCardComponent: Codable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let content: String
    public let icon: String?
    public let action: UIAction?

    public init(id: String, title: String, subtitle: String? = nil, content: String, icon: String? = nil, action: UIAction? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.icon = icon
        self.action = action
    }
}

public struct OptionCardsComponent: Codable, Equatable {
    public let cards: [OptionCardComponent]
    public let selectable: Bool
    public let layout: LayoutDirection

    public init(cards: [OptionCardComponent], selectable: Bool = true, layout: LayoutDirection = .vertical) {
        self.cards = cards
        self.selectable = selectable
        self.layout = layout
    }
}

public struct ToggleComponent: Codable, Equatable {
    public let label: String
    public let isOn: Bool
    public let action: UIAction

    public init(label: String, isOn: Bool = false, action: UIAction) {
        self.label = label
        self.isOn = isOn
        self.action = action
    }
}

public struct TabsComponent: Codable, Equatable {
    public let tabs: [TabItem]
    public let selectedIndex: Int

    public init(tabs: [TabItem], selectedIndex: Int = 0) {
        self.tabs = tabs
        self.selectedIndex = selectedIndex
    }
}

public struct TabItem: Codable, Equatable {
    public let label: String
    public let icon: String?
    public let content: [UIComponent]

    public init(label: String, icon: String? = nil, content: [UIComponent]) {
        self.label = label
        self.icon = icon
        self.content = content
    }
}

// MARK: - Content Components

public struct CodeBlockComponent: Codable, Equatable {
    public let code: String
    public let language: String
    public let showLineNumbers: Bool
    public let highlightLines: [Int]?
    public let copyable: Bool

    public init(code: String, language: String = "text", showLineNumbers: Bool = false, highlightLines: [Int]? = nil, copyable: Bool = true) {
        self.code = code
        self.language = language
        self.showLineNumbers = showLineNumbers
        self.highlightLines = highlightLines
        self.copyable = copyable
    }
}

public struct CodeComparisonComponent: Codable, Equatable {
    public let beforeCode: String
    public let afterCode: String
    public let language: String
    public let improvements: [String]?

    public init(beforeCode: String, afterCode: String, language: String = "text", improvements: [String]? = nil) {
        self.beforeCode = beforeCode
        self.afterCode = afterCode
        self.language = language
        self.improvements = improvements
    }
}

public struct QuoteComponent: Codable, Equatable {
    public let text: String
    public let author: String?
    public let style: QuoteStyle

    public init(text: String, author: String? = nil, style: QuoteStyle = .standard) {
        self.text = text
        self.author = author
        self.style = style
    }
}

public enum QuoteStyle: String, Codable, Equatable {
    case standard, highlight, warning
}

public struct CalloutComponent: Codable, Equatable {
    public let type: CalloutType
    public let title: String?
    public let message: String

    public init(type: CalloutType, title: String? = nil, message: String) {
        self.type = type
        self.title = title
        self.message = message
    }
}

public enum CalloutType: String, Codable, Equatable {
    case info, success, warning, error, tip
}

public struct DividerComponent: Codable, Equatable {
    public let style: DividerStyle
    public let label: String?

    public init(style: DividerStyle = .line, label: String? = nil) {
        self.style = style
        self.label = label
    }
}

public enum DividerStyle: String, Codable, Equatable {
    case line, dashed, gradient, space
}

// MARK: - Data Components

public struct KeyValueComponent: Codable, Equatable {
    public let key: String
    public let value: String
    public let icon: String?
    public let valueColor: String?

    public init(key: String, value: String, icon: String? = nil, valueColor: String? = nil) {
        self.key = key
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
}

public struct KeyValueListComponent: Codable, Equatable {
    public let items: [KeyValueComponent]
    public let layout: LayoutDirection

    public init(items: [KeyValueComponent], layout: LayoutDirection = .vertical) {
        self.items = items
        self.layout = layout
    }
}

public struct ProgressBarComponent: Codable, Equatable {
    public let value: Double  // 0.0 to 1.0
    public let label: String?
    public let showPercentage: Bool
    public let color: String?

    public init(value: Double, label: String? = nil, showPercentage: Bool = true, color: String? = nil) {
        self.value = value
        self.label = label
        self.showPercentage = showPercentage
        self.color = color
    }
}

public struct MetricComponent: Codable, Equatable {
    public let label: String
    public let value: String
    public let trend: MetricTrend?
    public let trendValue: String?
    public let icon: String?

    public init(label: String, value: String, trend: MetricTrend? = nil, trendValue: String? = nil, icon: String? = nil) {
        self.label = label
        self.value = value
        self.trend = trend
        self.trendValue = trendValue
        self.icon = icon
    }
}

public enum MetricTrend: String, Codable, Equatable {
    case up, down, neutral
}

public struct MetricsRowComponent: Codable, Equatable {
    public let metrics: [MetricComponent]

    public init(metrics: [MetricComponent]) {
        self.metrics = metrics
    }
}

// MARK: - Layout Components

public struct StackComponent: Codable, Equatable {
    public let direction: LayoutDirection
    public let spacing: SpacingSize
    public let alignment: LayoutAlignment
    public let children: [UIComponent]

    public init(direction: LayoutDirection = .vertical, spacing: SpacingSize = .md, alignment: LayoutAlignment = .leading, children: [UIComponent]) {
        self.direction = direction
        self.spacing = spacing
        self.alignment = alignment
        self.children = children
    }
}

public struct CardComponent: Codable, Equatable {
    public let title: String?
    public let subtitle: String?
    public let content: [UIComponent]
    public let style: CardStyle
    public let action: UIAction?

    public init(title: String? = nil, subtitle: String? = nil, content: [UIComponent], style: CardStyle = .elevated, action: UIAction? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.style = style
        self.action = action
    }
}

public enum CardStyle: String, Codable, Equatable {
    case flat, elevated, outlined, glass
}

public struct CollapsibleComponent: Codable, Equatable {
    public let title: String
    public let icon: String?
    public let isExpanded: Bool
    public let content: [UIComponent]

    public init(title: String, icon: String? = nil, isExpanded: Bool = true, content: [UIComponent]) {
        self.title = title
        self.icon = icon
        self.isExpanded = isExpanded
        self.content = content
    }
}

public struct SpacerComponent: Codable, Equatable {
    public let size: SpacingSize

    public init(size: SpacingSize = .md) {
        self.size = size
    }
}

// MARK: - Special Components

public struct ImageComponent: Codable, Equatable {
    public let source: ImageSource
    public let alt: String?
    public let size: ImageSize
    public let cornerRadius: CGFloat?

    public init(source: ImageSource, alt: String? = nil, size: ImageSize = .medium, cornerRadius: CGFloat? = 8) {
        self.source = source
        self.alt = alt
        self.size = size
        self.cornerRadius = cornerRadius
    }
}

public enum ImageSource: Codable, Equatable {
    case screenshot  // Reference to captured screenshot
    case systemIcon(String)
    case base64(String)
}

public enum ImageSize: String, Codable, Equatable {
    case small, medium, large, full
}

public struct BadgeComponent: Codable, Equatable {
    public let text: String
    public let style: BadgeStyle
    public let icon: String?

    public init(text: String, style: BadgeStyle = .default, icon: String? = nil) {
        self.text = text
        self.style = style
        self.icon = icon
    }
}

public enum BadgeStyle: String, Codable, Equatable {
    case `default`, success, warning, error, info
}

public struct ChipComponent: Codable, Equatable {
    public let text: String
    public let icon: String?
    public let selected: Bool
    public let action: UIAction?

    public init(text: String, icon: String? = nil, selected: Bool = false, action: UIAction? = nil) {
        self.text = text
        self.icon = icon
        self.selected = selected
        self.action = action
    }
}

public struct ChipsComponent: Codable, Equatable {
    public let chips: [ChipComponent]
    public let selectable: Bool
    public let multiSelect: Bool

    public init(chips: [ChipComponent], selectable: Bool = true, multiSelect: Bool = false) {
        self.chips = chips
        self.selectable = selectable
        self.multiSelect = multiSelect
    }
}

// MARK: - Actions

/// Actions that components can trigger
public struct UIAction: Codable, Equatable {
    public let type: ActionType
    public let payload: String?

    public init(type: ActionType, payload: String? = nil) {
        self.type = type
        self.payload = payload
    }
}

public enum ActionType: String, Codable, Equatable {
    case copy          // Copy payload to clipboard
    case speak         // Speak the payload using TTS
    case select        // Select this option (payload = option id)
    case navigate      // Navigate to URL (payload = url)
    case dismiss       // Dismiss the overlay
    case expand        // Expand/collapse
    case custom        // Custom action (payload = action identifier)
}

// MARK: - Schema Parsing

public class DynamicUISchemaParser {
    public init() {}

    /// Parse JSON string into DynamicUISchema
    public func parse(json: String) throws -> DynamicUISchema {
        guard let data = json.data(using: .utf8) else {
            throw DynamicUIParseError.invalidJSON
        }

        let decoder = JSONDecoder()
        return try decoder.decode(DynamicUISchema.self, from: data)
    }

    /// Parse JSON data into DynamicUISchema
    public func parse(data: Data) throws -> DynamicUISchema {
        let decoder = JSONDecoder()
        return try decoder.decode(DynamicUISchema.self, from: data)
    }
}

public enum DynamicUIParseError: Error {
    case invalidJSON
    case missingRequiredField(String)
    case invalidComponentType(String)
}
