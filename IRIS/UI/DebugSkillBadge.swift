//
//  DebugSkillBadge.swift
//  IRIS
//
//  Debug badge showing matched skill (DEBUG builds only)
//

import SwiftUI
import IRISCore

/// Shows the currently matched skill for debugging
/// Only visible in DEBUG builds
struct DebugSkillBadge: View {
    let skill: Skill?
    let suggestion: ProactiveSuggestion?

    @State private var isExpanded = false

    var body: some View {
        #if DEBUG
        if let skill = skill {
            skillBadgeContent(skill)
        }
        #endif
    }

    #if DEBUG
    @ViewBuilder
    private func skillBadgeContent(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main badge
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: skill.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan)

                    Text(skill.name)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))

                    if let suggestion = suggestion {
                        Text("\(Int(suggestion.confidence * 100))%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.green.opacity(0.8))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded details
            if isExpanded {
                expandedDetails(skill)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func expandedDetails(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Description
            Text(skill.description)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))

            // Capabilities
            HStack(spacing: 4) {
                Text("Caps:")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.7))

                ForEach(skill.capabilities, id: \.self) { cap in
                    Text(capabilityShortName(cap))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(3)
                }
            }

            // Actions
            HStack(spacing: 4) {
                Text("Acts:")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))

                ForEach(skill.allowedActions.prefix(4), id: \.self) { action in
                    Text(actionShortName(action))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(3)
                }

                if skill.allowedActions.count > 4 {
                    Text("+\(skill.allowedActions.count - 4)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Auto-execute info
            if skill.canAutoExecute {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                    Text("Auto-exec @ \(Int(skill.autoExecuteThreshold * 100))%")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.yellow.opacity(0.8))
                }
            }

            // Can act status
            if let suggestion = suggestion {
                HStack(spacing: 4) {
                    Circle()
                        .fill(suggestion.canAct ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(suggestion.canAct ? "Can Act" : "Display Only")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    if let preview = suggestion.actionPreview {
                        Text("→ \(preview)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.7))
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func capabilityShortName(_ cap: SkillCapability) -> String {
        switch cap {
        case .readScreen: return "screen"
        case .executeShell: return "shell"
        case .controlApps: return "apps"
        case .webSearch: return "web"
        case .clipboard: return "clip"
        case .fileSystem: return "files"
        case .apiCalls: return "api"
        case .typeText: return "type"
        }
    }

    private func actionShortName(_ action: SkillActionType) -> String {
        switch action {
        case .copy: return "copy"
        case .paste: return "paste"
        case .typeText: return "type"
        case .click: return "click"
        case .pressKey: return "key"
        case .openUrl: return "url"
        case .openApp: return "app"
        case .activateApp: return "activate"
        case .runCommand: return "cmd"
        case .runScript: return "script"
        case .readFile: return "read"
        case .writeFile: return "write"
        case .createFile: return "create"
        case .httpRequest: return "http"
        case .notify: return "notify"
        case .speak: return "speak"
        }
    }
    #endif
}

// MARK: - Skill Badge List

/// Shows badges for all matched skills
struct DebugSkillBadgeList: View {
    let suggestions: [ProactiveSuggestion]

    private let registry = SkillRegistry.shared

    var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 4) {
            ForEach(suggestions) { suggestion in
                if let skillId = suggestion.matchedSkill,
                   let skill = registry.skill(for: skillId) {
                    DebugSkillBadge(skill: skill, suggestion: suggestion)
                }
            }
        }
        #endif
    }
}

// MARK: - Compact Skill Indicator

/// Compact indicator for showing skill status
struct SkillIndicator: View {
    let skill: Skill?
    let canAct: Bool

    var body: some View {
        if let skill = skill {
            HStack(spacing: 4) {
                Image(systemName: skill.icon)
                    .font(.system(size: 10))
                    .foregroundColor(canAct ? .green : .gray)

                #if DEBUG
                Text(skill.id)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                #endif
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DebugSkillBadge_Previews: PreviewProvider {
    static var previews: some View {
        let testSkill = Skill(
            id: "code-improvement",
            name: "Code Improvement",
            description: "Refactor, optimize, and improve code quality",
            icon: "wand.and.stars",
            intents: ["improve"],
            capabilities: [.readScreen, .clipboard],
            allowedActions: [.copy, .paste, .typeText],
            canAutoExecute: false,
            autoExecuteThreshold: 0.9
        )

        let testSuggestion = ProactiveSuggestion(
            id: 1,
            intent: "improve",
            label: "Improve this code",
            confidence: 0.85,
            matchedSkill: "code-improvement",
            canAct: true,
            actionPreview: "Improve and copy to clipboard"
        )

        VStack(spacing: 20) {
            DebugSkillBadge(skill: testSkill, suggestion: testSuggestion)

            SkillIndicator(skill: testSkill, canAct: true)
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif
