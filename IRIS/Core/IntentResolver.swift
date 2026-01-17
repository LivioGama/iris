import Foundation
import IRISCore
import IRISNetwork

@MainActor
class IntentResolver: ObservableObject {
    @Published var lastResult: ResolvedIntent?
    @Published var isResolving = false
    
    private let geminiService = GeminiService()
    private let confidenceThreshold = 0.4
    
    var onResolved: ((ResolvedIntent) -> Void)?
    var onLowConfidence: ((ResolvedIntent) -> Void)?
    
    func resolve(
        fullScreenImage: String,
        croppedImage: String,
        transcript: String,
        gazePoint: CGPoint
    ) async throws -> ResolvedIntent {
        isResolving = true
        defer { isResolving = false }
        
        let response = try await geminiService.resolveIntent(
            fullScreenBase64: fullScreenImage,
            croppedRegionBase64: croppedImage,
            transcript: transcript,
            gazePoint: gazePoint
        )
        
        let intent = ResolvedIntent(
            target: response.target,
            action: response.action,
            reasoning: response.reasoning,
            confidence: response.confidence
        )
        
        lastResult = intent
        
        if intent.confidence >= confidenceThreshold {
            onResolved?(intent)
        } else {
            onLowConfidence?(intent)
        }
        
        return intent
    }
    
    func clearResult() {
        lastResult = nil
    }
}
