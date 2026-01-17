import Foundation
import CoreGraphics

public struct DetectedElement: Identifiable {
    public let id = UUID()
    public let bounds: CGRect
    public let label: String
    public let type: ElementType
    public let confidence: Double

    public init(bounds: CGRect, label: String, type: ElementType, confidence: Double) {
        self.bounds = bounds
        self.label = label
        self.type = type
        self.confidence = confidence
    }
}

public enum ElementType {
    case codeEditor
    case inputField
    case sidebar
    case panel
    case button
    case textRegion
    case window
    case other
}
