import SwiftUI
import IRISCore
import AppKit

// MARK: - Dynamic UI Renderer

/// Renders a DynamicUISchema into SwiftUI views
struct DynamicUIRenderer: View {
    let schema: DynamicUISchema
    let screenshot: NSImage?
    @State private var selectedOptionId: String? = nil
    @State private var expandedSections: Set<String> = []
    @State private var selectedTabIndex: Int = 0

    /// Action handler callback
    var onAction: ((UIAction) -> Void)?

    var body: some View {
        VStack(alignment: layoutAlignment, spacing: schema.layout.spacing.value) {
            // Mode badge if title exists
            if let title = schema.theme.title {
                modeBadge(title: title, icon: schema.theme.icon)
                    .padding(.horizontal, schema.layout.padding.value)
                    .padding(.top, schema.layout.padding.value)
            }

            // Screenshot if configured
            if let screenshotConfig = schema.screenshotConfig,
               screenshotConfig.visible,
               screenshotConfig.position == .top,
               let screenshot = screenshot {
                screenshotView(screenshot, config: screenshotConfig)
                    .padding(.horizontal, schema.layout.padding.value)
            }

            // Main content
            ScrollView {
                contentStack
                    .padding(.horizontal, schema.layout.padding.value)
                    .frame(maxWidth: schema.layout.maxWidth)
            }
            .padding(.bottom, schema.layout.padding.value)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
    }

    // MARK: - Layout Helpers

    private var layoutAlignment: HorizontalAlignment {
        switch schema.layout.alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private var backgroundColor: Color {
        switch schema.theme.background {
        case .dark:
            return Color(red: 20/255, green: 20/255, blue: 24/255, opacity: 0.92)
        case .darker:
            return Color(red: 15/255, green: 15/255, blue: 20/255, opacity: 0.95)
        case .warm:
            return Color(red: 30/255, green: 20/255, blue: 40/255, opacity: 0.92)
        case .cool:
            return Color(red: 15/255, green: 20/255, blue: 30/255, opacity: 0.95)
        case .glass:
            return Color.black.opacity(0.6)
        }
    }

    private var accentColor: Color {
        Color(hex: schema.theme.accentColor)
    }

    private var accentGradient: LinearGradient {
        if let secondary = schema.theme.secondaryColor {
            return LinearGradient(
                colors: [Color(hex: schema.theme.accentColor), Color(hex: secondary)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color(hex: schema.theme.accentColor), Color(hex: schema.theme.accentColor).opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Content Stack

    @ViewBuilder
    private var contentStack: some View {
        switch schema.layout.direction {
        case .vertical:
            VStack(alignment: layoutAlignment, spacing: schema.layout.spacing.value) {
                ForEach(Array(schema.components.enumerated()), id: \.offset) { _, component in
                    renderComponent(component)
                }
            }
        case .horizontal:
            HStack(alignment: .top, spacing: schema.layout.spacing.value) {
                ForEach(Array(schema.components.enumerated()), id: \.offset) { _, component in
                    renderComponent(component)
                }
            }
        case .grid:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: schema.layout.spacing.value) {
                ForEach(Array(schema.components.enumerated()), id: \.offset) { _, component in
                    renderComponent(component)
                }
            }
        case .splitHorizontal:
            HStack(alignment: .top, spacing: schema.layout.spacing.value) {
                if schema.components.count >= 2 {
                    VStack(alignment: .leading, spacing: IRISSpacing.md) {
                        renderComponent(schema.components[0])
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: IRISSpacing.md) {
                        renderComponent(schema.components[1])
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        case .splitVertical:
            VStack(spacing: schema.layout.spacing.value) {
                if schema.components.count >= 2 {
                    renderComponent(schema.components[0])
                    renderComponent(schema.components[1])
                }
            }
        }
    }

    // MARK: - Component Renderer

    private func renderComponent(_ component: UIComponent) -> AnyView {
        switch component {
        // Text components
        case .heading(let c):
            AnyView(renderHeading(c))
        case .paragraph(let c):
            AnyView(renderParagraph(c))
        case .label(let c):
            AnyView(renderLabel(c))

        // List components
        case .bulletList(let c):
            AnyView(renderBulletList(c))
        case .numberedList(let c):
            AnyView(renderNumberedList(c))
        case .checklist(let c):
            AnyView(renderChecklist(c))

        // Interactive components
        case .button(let c):
            AnyView(renderButton(c))
        case .buttonGroup(let c):
            AnyView(renderButtonGroup(c))
        case .optionCard(let c):
            AnyView(renderOptionCard(c))
        case .optionCards(let c):
            AnyView(renderOptionCards(c))
        case .toggle(let c):
            AnyView(renderToggle(c))
        case .tabs(let c):
            AnyView(renderTabs(c))

        // Content components
        case .codeBlock(let c):
            AnyView(renderCodeBlock(c))
        case .codeComparison(let c):
            AnyView(renderCodeComparison(c))
        case .quote(let c):
            AnyView(renderQuote(c))
        case .callout(let c):
            AnyView(renderCallout(c))
        case .divider(let c):
            AnyView(renderDivider(c))

        // Data components
        case .keyValue(let c):
            AnyView(renderKeyValue(c))
        case .keyValueList(let c):
            AnyView(renderKeyValueList(c))
        case .progressBar(let c):
            AnyView(renderProgressBar(c))
        case .metric(let c):
            AnyView(renderMetric(c))
        case .metricsRow(let c):
            AnyView(renderMetricsRow(c))

        // Layout components
        case .stack(let c):
            AnyView(renderStack(c))
        case .card(let c):
            AnyView(renderCard(c))
        case .collapsible(let c):
            AnyView(renderCollapsible(c))
        case .spacer(let c):
            AnyView(Spacer().frame(height: c.size.value))

        // Special components
        case .image(let c):
            AnyView(renderImage(c))
        case .badge(let c):
            AnyView(renderBadge(c))
        case .chip(let c):
            AnyView(renderChip(c))
        case .chips(let c):
            AnyView(renderChips(c))
        }
    }

    // MARK: - Text Components

    private func renderHeading(_ component: HeadingComponent) -> some View {
        HStack(spacing: IRISSpacing.xs) {
            if let icon = component.icon {
                Text(icon)
                    .font(.system(size: headingFontSize(component.level)))
            }

            Text(component.text)
                .font(.system(size: headingFontSize(component.level), weight: headingWeight(component.level), design: .rounded))
                .foregroundColor(IRISColors.textPrimary)
        }
        .padding(.top, component.level == 1 ? IRISSpacing.md : IRISSpacing.xs)
    }

    private func headingFontSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 28
        case 2: return 22
        default: return 18
        }
    }

    private func headingWeight(_ level: Int) -> Font.Weight {
        switch level {
        case 1: return .bold
        case 2: return .semibold
        default: return .medium
        }
    }

    private func renderParagraph(_ component: ParagraphComponent) -> some View {
        Text(component.text)
            .font(paragraphFont(component.style))
            .foregroundColor(paragraphColor(component.style))
            .lineSpacing(4)
    }

    private func paragraphFont(_ style: TextStyle) -> Font {
        switch style {
        case .body: return .system(size: 15, weight: .regular, design: .rounded)
        case .caption: return .system(size: 12, weight: .regular, design: .rounded)
        case .emphasized: return .system(size: 15, weight: .medium, design: .rounded)
        case .muted: return .system(size: 14, weight: .light, design: .rounded)
        case .highlight: return .system(size: 15, weight: .medium, design: .rounded)
        }
    }

    private func paragraphColor(_ style: TextStyle) -> Color {
        switch style {
        case .body: return IRISColors.textSecondary
        case .caption: return IRISColors.textTertiary
        case .emphasized: return IRISColors.textPrimary
        case .muted: return IRISColors.textDimmed
        case .highlight: return accentColor
        }
    }

    private func renderLabel(_ component: LabelComponent) -> some View {
        HStack(spacing: IRISSpacing.xs) {
            if let icon = component.icon {
                Text(icon)
                    .font(.system(size: 14))
            }

            Text(component.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(component.color.map { Color(hex: $0) } ?? IRISColors.textSecondary)
        }
    }

    // MARK: - List Components

    private func renderBulletList(_ component: BulletListComponent) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.xs) {
            ForEach(Array(component.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: IRISSpacing.xs) {
                    Text(bulletCharacter(component.bulletStyle))
                        .font(.system(size: 12))
                        .foregroundColor(accentColor)
                        .padding(.top, 3)

                    Text(item)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(IRISColors.textSecondary)
                }
            }
        }
    }

    private func bulletCharacter(_ style: BulletStyle) -> String {
        switch style {
        case .dot: return "•"
        case .dash: return "–"
        case .arrow: return "→"
        case .check: return "✓"
        case .star: return "★"
        }
    }

    private func renderNumberedList(_ component: NumberedListComponent) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.xs) {
            ForEach(Array(component.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: IRISSpacing.xs) {
                    Text("\(component.startFrom + index).")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(accentColor)
                        .frame(width: 24, alignment: .trailing)

                    Text(item)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(IRISColors.textSecondary)
                }
            }
        }
    }

    private func renderChecklist(_ component: ChecklistComponent) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.sm) {
            ForEach(Array(component.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: IRISSpacing.xs) {
                    Text(item.checked ? "✅" : "⏳")
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.text)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(IRISColors.textPrimary)
                            .strikethrough(item.checked, color: IRISColors.textDimmed)

                        if let assignee = item.assignee {
                            Text("→ \(assignee)")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(IRISColors.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Interactive Components

    private func renderButton(_ component: ButtonComponent) -> some View {
        Button(action: { onAction?(component.action) }) {
            HStack(spacing: IRISSpacing.xs) {
                if let icon = component.icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(component.label)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, IRISSpacing.md)
            .padding(.vertical, IRISSpacing.sm)
            .foregroundColor(buttonForeground(component.style))
            .background(buttonBackground(component.style))
            .cornerRadius(IRISRadius.normal)
        }
        .buttonStyle(.plain)
    }

    private func buttonForeground(_ style: IRISCore.ButtonStyle) -> Color {
        switch style {
        case .primary: return .white
        case .secondary: return IRISColors.textPrimary
        case .ghost: return accentColor
        case .destructive: return .white
        }
    }

    private func buttonBackground(_ style: IRISCore.ButtonStyle) -> some View {
        Group {
            switch style {
            case .primary:
                accentGradient
            case .secondary:
                Color.black.opacity(0.3)
            case .ghost:
                Color.clear
            case .destructive:
                Color.red.opacity(0.8)
            }
        }
    }

    private func renderButtonGroup(_ component: ButtonGroupComponent) -> some View {
        Group {
            if component.layout == .horizontal {
                HStack(spacing: IRISSpacing.sm) {
                    ForEach(Array(component.buttons.enumerated()), id: \.offset) { _, button in
                        renderButton(button)
                    }
                }
            } else {
                VStack(spacing: IRISSpacing.sm) {
                    ForEach(Array(component.buttons.enumerated()), id: \.offset) { _, button in
                        renderButton(button)
                    }
                }
            }
        }
    }

    private func renderOptionCard(_ component: OptionCardComponent) -> some View {
        let isSelected = selectedOptionId == component.id

        return Button(action: {
            selectedOptionId = component.id
            if let action = component.action {
                onAction?(action)
            }
        }) {
            VStack(alignment: .leading, spacing: IRISSpacing.xs) {
                HStack(spacing: IRISSpacing.xs) {
                    if let icon = component.icon {
                        Text(icon)
                            .font(.system(size: 16))
                    }

                    Text(component.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(IRISColors.textPrimary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(accentColor)
                    }
                }

                if let subtitle = component.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(accentColor)
                }

                Text(component.content)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(IRISColors.textSecondary)
                    .lineSpacing(4)
            }
            .padding(IRISSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: IRISRadius.normal)
                    .fill(Color.black.opacity(isSelected ? 0.4 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: IRISRadius.normal)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func renderOptionCards(_ component: OptionCardsComponent) -> some View {
        VStack(spacing: IRISSpacing.sm) {
            ForEach(Array(component.cards.enumerated()), id: \.offset) { _, card in
                renderOptionCard(card)
            }
        }
    }

    private func renderToggle(_ component: ToggleComponent) -> some View {
        HStack {
            Text(component.label)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(IRISColors.textSecondary)

            Spacer()

            Toggle("", isOn: .constant(component.isOn))
                .toggleStyle(SwitchToggleStyle(tint: accentColor))
        }
        .padding(IRISSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func renderTabs(_ component: TabsComponent) -> some View {
        VStack(spacing: IRISSpacing.md) {
            // Tab bar
            HStack(spacing: IRISSpacing.xs) {
                ForEach(Array(component.tabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: { selectedTabIndex = index }) {
                        HStack(spacing: IRISSpacing.xs) {
                            if let icon = tab.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 12))
                            }
                            Text(tab.label)
                                .font(.system(size: 14, weight: selectedTabIndex == index ? .semibold : .regular))
                        }
                        .padding(.horizontal, IRISSpacing.md)
                        .padding(.vertical, IRISSpacing.sm)
                        .foregroundColor(selectedTabIndex == index ? IRISColors.textPrimary : IRISColors.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: IRISRadius.tight)
                                .fill(selectedTabIndex == index ? accentColor.opacity(0.3) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(IRISSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: IRISRadius.normal)
                    .fill(Color.black.opacity(0.2))
            )

            // Tab content
            if selectedTabIndex < component.tabs.count {
                ForEach(Array(component.tabs[selectedTabIndex].content.enumerated()), id: \.offset) { _, child in
                    renderComponent(child)
                }
            }
        }
    }

    // MARK: - Content Components

    private func renderCodeBlock(_ component: CodeBlockComponent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(component.language.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(IRISColors.textSecondary)
                    .padding(.horizontal, IRISSpacing.xs)
                    .padding(.vertical, IRISSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )

                Spacer()

                if component.copyable {
                    Button(action: { copyToClipboard(component.code) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(IRISColors.textSecondary)
                        .padding(.horizontal, IRISSpacing.xs)
                        .padding(.vertical, IRISSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, IRISSpacing.sm)
            .padding(.vertical, IRISSpacing.xs)
            .background(Color.black.opacity(0.2))

            // Code content
            ScrollView(.horizontal) {
                Text(component.code)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(IRISColors.textPrimary)
                    .textSelection(.enabled)
                    .padding(IRISSpacing.sm)
            }
            .frame(maxHeight: 300)
        }
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.3))
        )
    }

    private func renderCodeComparison(_ component: CodeComparisonComponent) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.md) {
            // Improvements if provided
            if let improvements = component.improvements, !improvements.isEmpty {
                VStack(alignment: .leading, spacing: IRISSpacing.xs) {
                    Text("KEY IMPROVEMENTS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(accentColor)

                    ForEach(Array(improvements.enumerated()), id: \.offset) { _, improvement in
                        HStack(alignment: .top, spacing: IRISSpacing.xs) {
                            Text("✓")
                                .foregroundColor(IRISColors.success)
                            Text(improvement)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(IRISColors.textSecondary)
                        }
                    }
                }
                .padding(IRISSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: IRISRadius.normal)
                        .fill(Color.black.opacity(0.2))
                )
            }

            // Code comparison
            HStack(alignment: .top, spacing: IRISSpacing.md) {
                // Before
                VStack(alignment: .leading, spacing: IRISSpacing.xs) {
                    Text("BEFORE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(IRISColors.diffRemovedBorder)

                    ScrollView {
                        Text(component.beforeCode)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(IRISColors.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(IRISSpacing.sm)
                    }
                    .frame(maxHeight: 250)
                    .background(
                        RoundedRectangle(cornerRadius: IRISRadius.normal)
                            .fill(IRISColors.diffRemoved)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: IRISRadius.normal)
                            .stroke(IRISColors.diffRemovedBorder.opacity(0.5), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity)

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(IRISColors.textDimmed)
                    .padding(.top, 40)

                // After
                VStack(alignment: .leading, spacing: IRISSpacing.xs) {
                    HStack {
                        Text("AFTER")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(IRISColors.diffAddedBorder)

                        Spacer()

                        Button(action: { copyToClipboard(component.afterCode) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                Text("Copy")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(IRISColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView {
                        Text(component.afterCode)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(IRISColors.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(IRISSpacing.sm)
                    }
                    .frame(maxHeight: 250)
                    .background(
                        RoundedRectangle(cornerRadius: IRISRadius.normal)
                            .fill(IRISColors.diffAdded)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: IRISRadius.normal)
                            .stroke(IRISColors.diffAddedBorder.opacity(0.5), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func renderQuote(_ component: QuoteComponent) -> some View {
        HStack(spacing: IRISSpacing.sm) {
            Rectangle()
                .fill(quoteColor(component.style))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: IRISSpacing.xs) {
                Text(component.text)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .italic()
                    .foregroundColor(IRISColors.textSecondary)

                if let author = component.author {
                    Text("— \(author)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(IRISColors.textTertiary)
                }
            }
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.15))
        )
    }

    private func quoteColor(_ style: QuoteStyle) -> Color {
        switch style {
        case .standard: return accentColor
        case .highlight: return IRISColors.info
        case .warning: return IRISColors.warning
        }
    }

    private func renderCallout(_ component: CalloutComponent) -> some View {
        HStack(alignment: .top, spacing: IRISSpacing.sm) {
            Text(calloutIcon(component.type))
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: IRISSpacing.xs) {
                if let title = component.title {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(calloutColor(component.type))
                }

                Text(component.message)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(IRISColors.textSecondary)
            }
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(calloutColor(component.type).opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .stroke(calloutColor(component.type).opacity(0.3), lineWidth: 1)
        )
    }

    private func calloutIcon(_ type: CalloutType) -> String {
        switch type {
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .tip: return "💡"
        }
    }

    private func calloutColor(_ type: CalloutType) -> Color {
        switch type {
        case .info: return IRISColors.info
        case .success: return IRISColors.success
        case .warning: return IRISColors.warning
        case .error: return IRISColors.error
        case .tip: return accentColor
        }
    }

    private func renderDivider(_ component: DividerComponent) -> some View {
        Group {
            switch component.style {
            case .line:
                Rectangle()
                    .fill(IRISColors.divider)
                    .frame(height: 1)
            case .dashed:
                Rectangle()
                    .fill(IRISColors.divider)
                    .frame(height: 1)
                    .mask(
                        HStack(spacing: 4) {
                            ForEach(0..<50, id: \.self) { _ in
                                Rectangle()
                                    .frame(width: 8)
                            }
                        }
                    )
            case .gradient:
                Rectangle()
                    .fill(accentGradient)
                    .frame(height: 2)
                    .opacity(0.5)
            case .space:
                Spacer()
                    .frame(height: IRISSpacing.lg)
            }
        }
    }

    // MARK: - Data Components

    private func renderKeyValue(_ component: KeyValueComponent) -> some View {
        HStack {
            if let icon = component.icon {
                Text(icon)
                    .font(.system(size: 14))
            }

            Text(component.key)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(IRISColors.textSecondary)

            Spacer()

            Text(component.value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(component.valueColor.map { Color(hex: $0) } ?? IRISColors.textPrimary)
        }
    }

    private func renderKeyValueList(_ component: KeyValueListComponent) -> some View {
        VStack(spacing: IRISSpacing.sm) {
            ForEach(Array(component.items.enumerated()), id: \.offset) { _, item in
                renderKeyValue(item)
            }
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func renderProgressBar(_ component: ProgressBarComponent) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.xs) {
            if let label = component.label {
                HStack {
                    Text(label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(IRISColors.textSecondary)

                    Spacer()

                    if component.showPercentage {
                        Text("\(Int(component.value * 100))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(component.color.map { Color(hex: $0) } ?? accentColor)
                    }
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.3))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(component.color.map { Color(hex: $0) } ?? accentColor)
                        .frame(width: geometry.size.width * CGFloat(component.value))
                }
            }
            .frame(height: 8)
        }
    }

    private func renderMetric(_ component: MetricComponent) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.xs) {
            HStack(spacing: IRISSpacing.xs) {
                if let icon = component.icon {
                    Text(icon)
                        .font(.system(size: 14))
                }

                Text(component.label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(IRISColors.textSecondary)
            }

            HStack(alignment: .bottom, spacing: IRISSpacing.xs) {
                Text(component.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(IRISColors.textPrimary)

                if let trend = component.trend, let trendValue = component.trendValue {
                    HStack(spacing: 2) {
                        Text(trendIcon(trend))
                            .font(.system(size: 12))
                        Text(trendValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(trendColor(trend))
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(IRISSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func trendIcon(_ trend: MetricTrend) -> String {
        switch trend {
        case .up: return "↗"
        case .down: return "↘"
        case .neutral: return "→"
        }
    }

    private func trendColor(_ trend: MetricTrend) -> Color {
        switch trend {
        case .up: return IRISColors.success
        case .down: return IRISColors.error
        case .neutral: return IRISColors.textSecondary
        }
    }

    private func renderMetricsRow(_ component: MetricsRowComponent) -> some View {
        HStack(spacing: IRISSpacing.md) {
            ForEach(Array(component.metrics.enumerated()), id: \.offset) { _, metric in
                renderMetric(metric)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Layout Components

    private func renderStack(_ component: StackComponent) -> some View {
        Group {
            switch component.direction {
            case .vertical:
                VStack(alignment: stackAlignment(component.alignment), spacing: component.spacing.value) {
                    ForEach(Array(component.children.enumerated()), id: \.offset) { _, child in
                        renderComponent(child)
                    }
                }
            case .horizontal:
                HStack(alignment: .top, spacing: component.spacing.value) {
                    ForEach(Array(component.children.enumerated()), id: \.offset) { _, child in
                        renderComponent(child)
                    }
                }
            default:
                VStack(alignment: stackAlignment(component.alignment), spacing: component.spacing.value) {
                    ForEach(Array(component.children.enumerated()), id: \.offset) { _, child in
                        renderComponent(child)
                    }
                }
            }
        }
    }

    private func stackAlignment(_ alignment: LayoutAlignment) -> HorizontalAlignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private func renderCard(_ component: CardComponent) -> some View {
        VStack(alignment: .leading, spacing: IRISSpacing.sm) {
            if let title = component.title {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(IRISColors.textPrimary)

                    if let subtitle = component.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                }
            }

            ForEach(Array(component.content.enumerated()), id: \.offset) { _, child in
                renderComponent(child)
            }
        }
        .padding(IRISSpacing.md)
        .background(cardBackground(component.style))
        .overlay(cardOverlay(component.style))
        .cornerRadius(IRISRadius.normal)
    }

    @ViewBuilder
    private func cardBackground(_ style: CardStyle) -> some View {
        switch style {
        case .flat:
            Color.black.opacity(0.15)
        case .elevated:
            Color.black.opacity(0.25)
        case .outlined:
            Color.clear
        case .glass:
            Color.white.opacity(0.05)
        }
    }

    @ViewBuilder
    private func cardOverlay(_ style: CardStyle) -> some View {
        switch style {
        case .outlined:
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .stroke(IRISColors.stroke, lineWidth: 1)
        default:
            EmptyView()
        }
    }

    private func renderCollapsible(_ component: CollapsibleComponent) -> some View {
        let isExpanded = expandedSections.contains(component.title)

        return VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded {
                        expandedSections.remove(component.title)
                    } else {
                        expandedSections.insert(component.title)
                    }
                }
            }) {
                HStack {
                    if let icon = component.icon {
                        Text(icon)
                            .font(.system(size: 14))
                    }

                    Text(component.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(IRISColors.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(IRISColors.textSecondary)
                }
                .padding(IRISSpacing.md)
                .background(Color.black.opacity(0.2))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: IRISSpacing.sm) {
                    ForEach(Array(component.content.enumerated()), id: \.offset) { _, child in
                        renderComponent(child)
                    }
                }
                .padding(IRISSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.normal)
                .fill(Color.black.opacity(0.1))
        )
        .onAppear {
            if component.isExpanded {
                expandedSections.insert(component.title)
            }
        }
    }

    // MARK: - Special Components

    @ViewBuilder
    private func renderImage(_ component: ImageComponent) -> some View {
        switch component.source {
        case .screenshot:
            if let screenshot = screenshot {
                Image(nsImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: imageMaxHeight(component.size))
                    .clipShape(RoundedRectangle(cornerRadius: component.cornerRadius ?? 8))
            }
        case .systemIcon(let name):
            Image(systemName: name)
                .font(.system(size: imageFontSize(component.size)))
                .foregroundColor(accentColor)
        case .base64:
            // Base64 image rendering not implemented in this version
            EmptyView()
        }
    }

    private func imageMaxHeight(_ size: ImageSize) -> CGFloat {
        switch size {
        case .small: return 100
        case .medium: return 200
        case .large: return 350
        case .full: return .infinity
        }
    }

    private func imageFontSize(_ size: ImageSize) -> CGFloat {
        switch size {
        case .small: return 24
        case .medium: return 48
        case .large: return 72
        case .full: return 96
        }
    }

    private func renderBadge(_ component: BadgeComponent) -> some View {
        HStack(spacing: IRISSpacing.xxs) {
            if let icon = component.icon {
                Text(icon)
                    .font(.system(size: 10))
            }

            Text(component.text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, IRISSpacing.sm)
        .padding(.vertical, IRISSpacing.xxs)
        .foregroundColor(badgeColor(component.style))
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.tight)
                .fill(badgeColor(component.style).opacity(0.2))
        )
    }

    private func badgeColor(_ style: BadgeStyle) -> Color {
        switch style {
        case .default: return IRISColors.textSecondary
        case .success: return IRISColors.success
        case .warning: return IRISColors.warning
        case .error: return IRISColors.error
        case .info: return IRISColors.info
        }
    }

    private func renderChip(_ component: ChipComponent) -> some View {
        Button(action: {
            if let action = component.action {
                onAction?(action)
            }
        }) {
            HStack(spacing: IRISSpacing.xxs) {
                if let icon = component.icon {
                    Text(icon)
                        .font(.system(size: 12))
                }

                Text(component.text)
                    .font(.system(size: 13, weight: component.selected ? .semibold : .regular, design: .rounded))
            }
            .padding(.horizontal, IRISSpacing.sm)
            .padding(.vertical, IRISSpacing.xs)
            .foregroundColor(component.selected ? .white : IRISColors.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: IRISRadius.soft)
                    .fill(component.selected ? accentColor : Color.black.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
    }

    private func renderChips(_ component: ChipsComponent) -> some View {
        FlowLayout(spacing: IRISSpacing.xs) {
            ForEach(Array(component.chips.enumerated()), id: \.offset) { _, chip in
                renderChip(chip)
            }
        }
    }

    // MARK: - Helper Views

    private func modeBadge(title: String, icon: String?) -> some View {
        HStack(spacing: IRISSpacing.xs) {
            if let icon = icon {
                Text(icon)
                    .font(.system(size: 14))
            }

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(IRISColors.textSecondary)
        }
        .padding(.horizontal, IRISSpacing.sm)
        .padding(.vertical, IRISSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: IRISRadius.tight)
                .fill(Color.black.opacity(0.2))
        )
    }

    private func screenshotView(_ screenshot: NSImage, config: ScreenshotDisplayConfig) -> some View {
        Image(nsImage: screenshot)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: config.size.maxDimension)
            .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius ?? 12))
            .overlay(
                Group {
                    if config.showBorder {
                        RoundedRectangle(cornerRadius: config.cornerRadius ?? 12)
                            .stroke(IRISColors.stroke, lineWidth: 1)
                    }
                }
            )
            .opacity(config.opacity)
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Flow Layout for Chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + lineHeight
        }
    }
}
