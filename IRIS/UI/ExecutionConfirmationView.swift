//
//  ExecutionConfirmationView.swift
//  IRIS
//
//  Enhanced execution confirmation with improved glassmorphism
//

import SwiftUI
import IRISCore

/// View to confirm execution of an action plan
struct ExecutionConfirmationView: View {
    let plan: ActionPlan
    let skill: Skill?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isExpanded = false
    @State private var isConfirmHovered = false
    @State private var isCancelHovered = false
    
    var body: some View {
        VStack(spacing: 14) {
            // Header with skill info
            headerSection
            
            // Action preview
            actionPreview
            
            // Expanded details
            if isExpanded {
                expandedDetails
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Action buttons
            actionButtons
            
            // Voice command hint
            voiceHint
        }
        .padding(18)
        .background(
            ZStack {
                // Base glass material
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                IRISProductionColors.geminiBlue.opacity(0.08),
                                IRISProductionColors.geminiPurple.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 10) {
            // Skill icon with glow
            skillIcon
            
            // Skill name
            if let skill = skill {
                Text(skill.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, IRISProductionColors.geminiBlue.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else {
                Text("Execute Actions")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Expand/collapse button
            Button(action: { 
                withAnimation(.easeInOut(duration: IRISAnimationTiming.quick)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .irisHover(scale: 1.1, lift: 0)
        }
    }
    
    private var skillIcon: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 36, height: 36)
            
            // Icon background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            IRISProductionColors.geminiBlue.opacity(0.2),
                            IRISProductionColors.geminiPurple.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
            
            Image(systemName: skill?.icon ?? "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(IRISProductionColors.geminiBlue)
        }
    }
    
    // MARK: - Action Preview
    
    private var actionPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("This will:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(IRISProductionColors.geminiBlue)
                        .frame(width: 18, alignment: .trailing)
                    
                    ZStack {
                        Circle()
                            .fill(colorForActionType(step.action.type).opacity(0.2))
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: iconForActionType(step.action.type))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(colorForActionType(step.action.type))
                    }
                    
                    Text(step.description)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(isExpanded ? nil : 1)
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Expanded Details
    
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(plan.steps, id: \.id) { step in
                if !step.action.parameters.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.description)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        ForEach(Array(step.action.parameters.keys.sorted()), id: \.self) { key in
                            if let value = step.action.parameters[key] {
                                HStack(spacing: 6) {
                                    Text("\(key):")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    Text(truncateValue(value))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button(action: onCancel) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        
                        if isCancelHovered {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(isCancelHovered ? 0.2 : 0.12), lineWidth: 0.5)
                )
                .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                withAnimation(.easeOut(duration: IRISAnimationTiming.quick)) {
                    isCancelHovered = isHovering
                }
            }
            .scaleEffect(isCancelHovered ? 1.03 : 1.0)
            
            // Execute button
            Button(action: onConfirm) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Execute")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        // Base gradient
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        IRISProductionColors.geminiBlue.opacity(isConfirmHovered ? 0.8 : 0.6),
                                        IRISProductionColors.geminiPurple.opacity(isConfirmHovered ? 0.7 : 0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Highlight on hover
                        if isConfirmHovered {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(isConfirmHovered ? 0.4 : 0.25), lineWidth: 0.5)
                )
                .foregroundColor(.white)
                .shadow(
                    color: IRISProductionColors.geminiBlue.opacity(isConfirmHovered ? 0.4 : 0.2),
                    radius: isConfirmHovered ? 15 : 8,
                    x: 0,
                    y: isConfirmHovered ? 5 : 3
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                withAnimation(.easeOut(duration: IRISAnimationTiming.quick)) {
                    isConfirmHovered = isHovering
                }
            }
            .scaleEffect(isConfirmHovered ? 1.03 : 1.0)
        }
    }
    
    // MARK: - Voice Hint
    
    private var voiceHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.system(size: 9))
                .foregroundColor(IRISProductionColors.geminiBlue.opacity(0.6))
            
            Text("Say \"do it\" to execute or \"cancel\" to abort")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.top, 4)
    }
    
    // MARK: - Helpers
    
    private func iconForActionType(_ type: SkillActionType) -> String {
        switch type {
        case .copy: return "doc.on.clipboard"
        case .paste: return "doc.on.doc"
        case .typeText: return "keyboard"
        case .click: return "cursorarrow.click"
        case .pressKey: return "command"
        case .openUrl: return "safari"
        case .openApp: return "app"
        case .activateApp: return "macwindow"
        case .runCommand: return "terminal"
        case .runScript: return "scroll"
        case .readFile: return "doc.text"
        case .writeFile: return "pencil"
        case .createFile: return "doc.badge.plus"
        case .httpRequest: return "network"
        case .notify: return "bell"
        case .speak: return "speaker.wave.2"
        case .scroll: return "arrow.up.arrow.down"
        }
    }
    
    private func colorForActionType(_ type: SkillActionType) -> Color {
        switch type {
        case .copy, .paste: return Color(hex: "3B82F6")
        case .typeText, .click, .pressKey: return Color(hex: "10B981")
        case .openUrl, .openApp, .activateApp: return Color(hex: "F59E0B")
        case .runCommand, .runScript: return Color(hex: "8B5CF6")
        case .readFile, .writeFile, .createFile: return Color(hex: "06B6D4")
        case .httpRequest: return Color(hex: "EC4899")
        case .notify, .speak: return Color(hex: "FBBF24")
        case .scroll: return Color(hex: "9CA3AF")
        }
    }
    
    private func truncateValue(_ value: String, maxLength: Int = 50) -> String {
        if value.count > maxLength {
            return String(value.prefix(maxLength)) + "..."
        }
        return value
    }
}

// MARK: - Execution Progress View

/// Shows execution progress while skill is running
struct ExecutionProgressView: View {
    let progress: String
    let isExecuting: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if isExecuting {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 18, height: 18)
                    .progressViewStyle(CircularProgressViewStyle(tint: IRISProductionColors.geminiBlue))
            } else {
                Image(systemName: progress.hasPrefix("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(progress.hasPrefix("✅") ? Color(hex: "10B981") : Color(hex: "EF4444"))
            }
            
            Text(progress)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ExecutionConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePlan = ActionPlan(
            skillId: "code-improvement",
            description: "Improve code quality",
            steps: [
                ActionStep(
                    description: "Copy improved code to clipboard",
                    action: Action.copy("const foo = 'bar';")
                ),
                ActionStep(
                    description: "Show notification",
                    action: Action.notify("Code copied!")
                )
            ],
            requiresConfirmation: true
        )
        
        let sampleSkill = Skill(
            id: "code-improvement",
            name: "Code Improvement",
            description: "Refactor and improve code quality",
            icon: "wand.and.stars",
            intents: ["improve", "refactor"],
            capabilities: [.readScreen, .clipboard],
            allowedActions: [.copy, .notify]
        )
        
        ZStack {
            Color.black.ignoresSafeArea()
            
            ExecutionConfirmationView(
                plan: samplePlan,
                skill: sampleSkill,
                onConfirm: { print("Confirmed") },
                onCancel: { print("Cancelled") }
            )
            .frame(width: 340)
        }
    }
}
#endif
