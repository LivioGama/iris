import Foundation
import ApplicationServices
import AppKit
import IRISCore

/// Native Accessibility API-based element detector
/// Replaces manual pixel scanning with OS-provided element information
public class AccessibilityElementDetector {

    public init() {}

    /// Detect UI element at a specific point using Accessibility API
    public func detectElement(at point: CGPoint) -> DetectedElement? {
        // Get the element at this point using Accessibility API
        var element: AXUIElement?
        let systemWideElement = AXUIElementCreateSystemWide()

        let result = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &element
        )

        guard result == .success, let axElement = element else {
            return nil
        }

        // Get element properties
        guard let bounds = getElementBounds(axElement),
              let role = getElementRole(axElement) else {
            return nil
        }

        let label = getElementLabel(axElement) ?? role
        let elementType = mapRoleToElementType(role)

        return DetectedElement(
            bounds: bounds,
            label: label,
            type: elementType,
            confidence: 1.0  // Accessibility API is always accurate
        )
    }

    // MARK: - Accessibility Helpers

    private func getElementBounds(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        if let positionValue = positionValue {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        }

        if let sizeValue = sizeValue {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }

        return CGRect(origin: position, size: size)
    }

    private func getElementRole(_ element: AXUIElement) -> String? {
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success else {
            return nil
        }
        return roleValue as? String
    }

    private func getElementLabel(_ element: AXUIElement) -> String? {
        // Try title first
        var titleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
           let title = titleValue as? String, !title.isEmpty {
            return title
        }

        // Try description
        var descValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descValue) == .success,
           let desc = descValue as? String, !desc.isEmpty {
            return desc
        }

        // Try value
        var valueValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueValue) == .success,
           let value = valueValue as? String, !value.isEmpty {
            return value
        }

        return nil
    }

    private func mapRoleToElementType(_ role: String) -> ElementType {
        switch role {
        case "AXButton":
            return .button
        case "AXTextField", "AXTextArea":
            return .textField
        case "AXStaticText":
            return .text
        case "AXImage":
            return .image
        case "AXWindow":
            return .window
        case "AXMenuButton", "AXPopUpButton":
            return .menu
        case "AXLink":
            return .link
        default:
            return .unknown
        }
    }
}
