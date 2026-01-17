import Foundation

/// Represents the different types of Interactive Context-Oriented Interface (ICOI) intents
/// that IRIS can handle based on user voice commands
public enum ICOIIntent: String, CaseIterable {
    case messageReply = "messageReply"
    case codeImprovement = "codeImprovement"
    case summarize = "summarize"
    case toneFeedback = "toneFeedback"
    case chartAnalysis = "chartAnalysis"
    case general = "general"

    /// Human-readable description of each intent
    public var description: String {
        switch self {
        case .messageReply:
            return "Generate empathetic message replies"
        case .codeImprovement:
            return "Provide better code implementations"
        case .summarize:
            return "Transform text into structured summaries"
        case .toneFeedback:
            return "Analyze tone and rewrite professionally"
        case .chartAnalysis:
            return "Explain graphs and data visualizations"
        case .general:
            return "General AI assistance"
        }
    }

    /// Keywords and phrases that trigger this intent (both English and French)
    public var keywords: [String] {
        switch self {
        case .messageReply:
            return [
                // Direct reply requests
                "respond", "reply", "answer", "what to say", "how to respond", "suggest reply",
                "help me respond", "help me reply", "message back", "write back",
                // French
                "répondre", "réponse", "que dire", "comment répondre", "suggérer réponse",
                "m'aider à répondre"
            ]
        case .codeImprovement:
            return [
                // Code improvement
                "improve code", "improve this", "better code", "fix code", "optimize",
                "refactor", "make better", "clean up", "enhance", "code review",
                "better implementation", "improve implementation", "fix this code",
                "make this better", "help with code", "code help", "improve function",
                "better version", "rewrite code",
                // French
                "améliorer", "améliorer code", "meilleur code", "corriger code",
                "refactorer", "optimiser", "rendre meilleur", "révision code"
            ]
        case .summarize:
            return [
                // Summarization
                "summarize", "summary", "key points", "main points", "recap",
                "tldr", "brief", "overview", "highlights", "sum up", "condensed",
                "action items", "takeaways", "main ideas", "executive summary",
                // French
                "résumer", "résumé", "points clés", "principaux points", "récapitulatif",
                "grandes lignes", "synthèse"
            ]
        case .toneFeedback:
            return [
                // Tone analysis and rewriting
                "tone", "professional", "rewrite", "rephrase", "formal", "informal",
                "polite", "diplomatic", "friendlier", "more professional", "better tone",
                "tone analysis", "analyze tone", "make professional", "sound better",
                "improve tone", "soften", "stronger", "nicer",
                // French
                "ton", "professionnel", "réécrire", "reformuler", "formel", "poli",
                "diplomatique", "analyser ton", "ton professionnel"
            ]
        case .chartAnalysis:
            return [
                // Chart and graph analysis
                "graph", "chart", "data", "visualization", "plot", "diagram",
                "explain graph", "explain chart", "what does this show", "analyze chart",
                "trends", "statistics", "numbers", "metrics", "dashboard",
                // French
                "graphique", "tableau", "données", "visualisation", "diagramme",
                "expliquer graphique", "analyser graphique", "tendances", "statistiques"
            ]
        case .general:
            return [] // Fallback for unmatched requests
        }
    }
}

/// Result of intent classification including confidence score
public struct IntentClassification {
    public let intent: ICOIIntent
    public let confidence: Double
    public let matchedKeywords: [String]

    public init(intent: ICOIIntent, confidence: Double, matchedKeywords: [String] = []) {
        self.intent = intent
        self.confidence = confidence
        self.matchedKeywords = matchedKeywords
    }
}
