import Foundation
import CoreGraphics

struct DetectedElement: Identifiable {
    let id = UUID()
    let bounds: CGRect
    let label: String
    let type: ElementType
    let confidence: Double
}

enum ElementType {
    case codeEditor
    case inputField
    case sidebar
    case panel
    case button
    case textRegion
    case window
    case other
}
