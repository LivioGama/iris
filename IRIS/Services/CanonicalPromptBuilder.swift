import Foundation
import CoreGraphics
import IRISCore

/// Builds canonical prompts for Gemini that enforce UI-object-level reasoning
/// Based on the canonical strategy: rectangle = UI object candidate, dot = supporting signal
public class CanonicalPromptBuilder {

    public init() {}

    // MARK: - Semantic Prompt Building

    /// Builds a semantic prompt that enforces UI-object reasoning
    /// - Parameters:
    ///   - detectedElement: The detected UI element
    ///   - gazePoint: Current gaze point (optional - for dot visualization)
    ///   - userRequest: User's voice request
    /// - Returns: Canonical prompt string
    public func buildSemanticPrompt(
        detectedElement: DetectedElement,
        gazePoint: CGPoint?,
        userRequest: String
    ) -> String {
        let systemMessage = """
        You're having a natural conversation with someone using voice. They're looking at their screen and asking you about what they see.

        The blue rectangle shows what they're looking at. Answer their question directly - like you're talking to a friend, not writing a report.

        Key principles:
        - Talk like a human, not a system
        - Go straight to the answer - no "The detected object is..." or "Based on the screenshot..."
        - If they ask "explain this", dig deep into the meaning, implications, and context - don't just repeat what's visible
        - If they ask "what is this", give a quick, sharp answer
        - Never mention technical details (pixels, coordinates, detection, rectangle, etc.) unless they specifically ask
        - Be conversational but efficient
        - Assume they're smart - don't over-explain obvious things

        """

        let contextInfo = buildContextInfo(
            detectedElement: detectedElement,
            gazePoint: gazePoint,
            userRequest: userRequest
        )

        return systemMessage + contextInfo
    }

    // MARK: - Context Building

    /// Builds the context information section
    private func buildContextInfo(
        detectedElement: DetectedElement,
        gazePoint: CGPoint?,
        userRequest: String
    ) -> String {
        // Determine response style based on question type
        let needsDepth = userRequest.lowercased().contains("explain") ||
                        userRequest.lowercased().contains("what does this mean") ||
                        userRequest.lowercased().contains("understand") ||
                        userRequest.lowercased().contains("why") ||
                        userRequest.lowercased().contains("how does")

        let context = """

        They're asking: "\(userRequest.isEmpty ? "What am I looking at?" : userRequest)"

        \(needsDepth ?
        "They want understanding - explain the meaning, implications, and context. Don't just describe what's visible." :
        "Give a quick, direct answer. Keep it sharp and to the point.")

        Plain text only - no markdown, asterisks, or formatting.
        """

        return context
    }

    // MARK: - Formatting

    /// Formats element type for display
    private func formatElementType(_ type: ElementType) -> String {
        switch type {
        case .codeEditor:
            return "Code Editor"
        case .inputField:
            return "Input Field"
        case .sidebar:
            return "Sidebar/Navigation"
        case .panel:
            return "Panel/Content Area"
        case .button:
            return "Button"
        case .textRegion:
            return "Text Region"
        case .window:
            return "Window"
        case .textField:
            return "Text Field"
        case .text:
            return "Text"
        case .image:
            return "Image"
        case .menu:
            return "Menu"
        case .link:
            return "Link"
        case .unknown:
            return "Unknown Element"
        case .other:
            return "UI Element"
        }
    }
}
