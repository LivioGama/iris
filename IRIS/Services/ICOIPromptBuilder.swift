import Foundation
import IRISCore

/// Builds specialized prompts for different ICOI use cases
/// Each prompt is optimized for the specific intent and response format
public class ICOIPromptBuilder {

    public init() {}

    /// Builds the appropriate prompt based on classified intent
    public func buildPrompt(for intent: ICOIIntent, userRequest: String, focusedElement: DetectedElement?) -> String {
        switch intent {
        case .messageReply:
            return buildMessageReplyPrompt(userRequest: userRequest, focusedElement: focusedElement)
        case .codeImprovement:
            return buildCodeImprovementPrompt(userRequest: userRequest)
        case .summarize:
            return buildSummarizationPrompt(userRequest: userRequest)
        case .toneFeedback:
            return buildToneFeedbackPrompt(userRequest: userRequest)
        case .chartAnalysis:
            return buildChartAnalysisPrompt(userRequest: userRequest)
        case .general:
            return buildGeneralPrompt(userRequest: userRequest, focusedElement: focusedElement)
        }
    }

    /// Generates prompt for instant message reply generation
    private func buildMessageReplyPrompt(userRequest: String, focusedElement: DetectedElement?) -> String {
        var contextInfo = ""
        if let element = focusedElement {
            let width = element.bounds.width
            let height = element.bounds.height
            contextInfo = """

            🎯 FOCUSED REGION (HIGHLIGHTED IN BLUE):
            The screenshot contains a BLUE BOUNDING BOX marking the area the user is focused on.
            - Label: "\(element.label)"
            - Type: \(element.type)
            - Bounding Box: x=\(Int(element.bounds.minX)), y=\(Int(element.bounds.minY)), width=\(Int(width)), height=\(Int(height))
            - The BLUE BORDERED RECTANGLE marks the exact region the user is looking at
            - Focus on content INSIDE this blue box while using surrounding context for better understanding
            """
        }

        return """
        🌍 CRITICAL: Respond in the EXACT same language as the user's request below.

        User request: "\(userRequest)"\(contextInfo)

        IDENTITY RULES:
        - USER (you're helping) = RIGHT side messages (blue/green bubbles)
        - OTHER PERSON = LEFT side messages (gray/white bubbles)
        - Generate responses the USER should send to the OTHER PERSON

        TASK: Provide 3 brief reply options (under 50 words each):

        **Option 1: Empathetic**
        [warm, understanding response]

        **Option 2: Concise**
        [brief, direct response]

        **Option 3: Assertive**
        [clear boundaries, professional]

        Be direct. Match the conversation's language and tone.
        """
    }

    /// Generates prompt for code improvement suggestions
    private func buildCodeImprovementPrompt(userRequest: String) -> String {
        """
        🌍 CRITICAL: Respond in the EXACT same language as the user's request below.

        User request: "\(userRequest)"

        TASK: Extract code, provide improved version, explain changes briefly.

        FORMAT:
        ## Improved Code
        ```[language]
        [improved code]
        ```

        ## Key Improvements
        - [improvement 1]
        - [improvement 2]
        - [improvement 3]

        Be concise. Focus on readability and best practices.
        """
    }

    /// Generates prompt for meeting/document summarization
    private func buildSummarizationPrompt(userRequest: String) -> String {
        """
        🌍 CRITICAL: Respond in the EXACT same language as the user's request below.

        User request: "\(userRequest)"

        TASK: Create a concise structured summary:

        ## Main Points
        - [key point 1]
        - [key point 2]

        ## Actions
        - [who]: [what] - [when]

        ## Decisions
        - [decision 1]
        - [decision 2]

        ## Open Items
        - [blocker or question]

        Extract only essential information. Be direct.
        """
    }

    /// Generates prompt for tone analysis and rewriting
    private func buildToneFeedbackPrompt(userRequest: String) -> String {
        """
        🌍 CRITICAL LANGUAGE REQUIREMENT 🌍
        You MUST respond in the EXACT same language as the user's request below.
        If the user request is in French, respond in French.
        If the user request is in Spanish, respond in Spanish.
        This applies to ALL text including section headers and rewrites.

        User request: "\(userRequest)"

        TASK: Extract text, analyze tone briefly, provide 3 rewritten versions ALL in the same language as the user's request.

        FORMAT (translate headers to match user's language):
        ## Tone Analysis
        - Current tone: [brief description]
        - Potential issues: [if any]

        ## Professional Version
        [rewrite in user's language]

        ## Friendly Version
        [rewrite in user's language]

        ## Diplomatic Version
        [rewrite in user's language]

        Keep rewrites concise and natural. EVERYTHING must be in the user's input language.
        """
    }

    /// Generates prompt for chart and graph analysis
    private func buildChartAnalysisPrompt(userRequest: String) -> String {
        """
        🌍 CRITICAL: Respond in the EXACT same language as the user's request below.

        User request: "\(userRequest)"

        TASK: Analyze the chart and provide:

        ## Main Trends
        - [trend with specific numbers]
        - [trend with specific numbers]

        ## Key Insight
        [One sentence summary with data]

        ## Suggested Title
        "[Descriptive title]"

        Be specific. Include actual numbers from the chart.
        """
    }

    /// Generates a general-purpose prompt as fallback
    private func buildGeneralPrompt(userRequest: String, focusedElement: DetectedElement?) -> String {
        var prompt = """
        🌍 CRITICAL: Respond in the EXACT same language as the user's request below.

        You are helping a user with eye-tracking and voice control.
        """

        if let element = focusedElement {
            let centerX = element.bounds.midX
            let centerY = element.bounds.midY
            let width = element.bounds.width
            let height = element.bounds.height

            prompt += """


            🎯 FOCUSED REGION (HIGHLIGHTED IN BLUE):
            The screenshot contains a BLUE BOUNDING BOX marking the area the user is focused on.
            - Label: "\(element.label)"
            - Type: \(element.type)
            - Bounding Box: x=\(Int(element.bounds.minX)), y=\(Int(element.bounds.minY)), width=\(Int(width)), height=\(Int(height))
            - Center: (\(Int(centerX)), \(Int(centerY)))
            - The BLUE BORDERED RECTANGLE marks the exact region the user is looking at
            - Focus on content INSIDE this blue box while using surrounding context for better understanding
            """
        }

        prompt += """


        MESSAGING APP RULES (if applicable):
        - RIGHT side = USER (person you're helping)
        - LEFT side = OTHER PERSON
        - Analyze from USER's perspective
        - When asked about sentiment: analyze what OTHER PERSON sent TO the USER
        - When asked for replies: suggest what USER should send back

        User request: "\(userRequest.isEmpty ? "What am I looking at?" : userRequest)"

        Response rules:
        - Be direct and brief (2-3 sentences unless more detail requested)
        - Use plain text only - NO markdown, NO asterisks, NO formatting
        - Answer from USER's perspective
        - Match the language of the user's request
        """

        return prompt
    }
}
