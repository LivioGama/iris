import Foundation
import CoreGraphics
import ApplicationServices
import AppKit
import IRISCore

extension CGRect {
    var area: CGFloat {
        return width * height
    }
}

public class AccessibilityDetector {
    private let systemWideElement: AXUIElement

    public init() {
        systemWideElement = AXUIElementCreateSystemWide()
    }

    public func findElement(at point: CGPoint) -> DetectedElement? {
        guard let initialElement = getElementAt(point: point) else {
            return nil
        }

        // Get screen size first
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let screenArea = screenSize.width * screenSize.height

        // Start from the initial element
        // Windows/Groups might have useful children, so check them first
        var element = initialElement
        if let initialRole = getElementRole(initialElement),
           (initialRole == "AXWindow" || initialRole == "AXGroup"),
           let children = getElementChildren(initialElement), !children.isEmpty {
            // Find child at point to start from
            for child in children {
                if let childBounds = getElementBounds(child),
                   childBounds.contains(point) {
                    element = child
                    break
                }
            }
        }

        // Now walk up hierarchy from the element (which might be a child or the original element)

        var bestCandidate: (element: AXUIElement, bounds: CGRect, role: String)? = nil
        var smallestReasonableCandidate: (element: AXUIElement, bounds: CGRect, role: String)? = nil
        var largestArea: CGFloat = 0
        var allElements: [(element: AXUIElement, role: String, bounds: CGRect)] = []
        let maxReasonableArea = screenArea * 0.6 // Elements should be < 60% of screen

        // Walk up the hierarchy to find a high-level structural element
        var maxDepth = 10 // Prevent infinite loops
        while maxDepth > 0 {
            maxDepth -= 1

            guard let bounds = getElementBounds(element),
                  let role = getElementRole(element) else {
                // Try parent
                if let parent = getParentElement(element) {
                    element = parent
                    continue
                }
                break
            }

            // Log all elements we encounter
            allElements.append((element, role, bounds))

            let area = bounds.area

            // Prefer SMALLEST reasonable element (not too tiny, not screen-sized)
            if area >= 3000 && area <= maxReasonableArea {
                if smallestReasonableCandidate == nil || area < smallestReasonableCandidate!.bounds.area {
                    smallestReasonableCandidate = (element, bounds, role)
                }
            }

            // Track the largest element as backup (but not screen-sized)
            if area > largestArea && bounds.width > 50 && bounds.height > 30 && area < maxReasonableArea {
                largestArea = area
                bestCandidate = (element, bounds, role)
            }

            // Check if this is a high-level structural element
            if isHighLevelElement(role, bounds: bounds) {
                let type = mapRoleToElementType(role)
                let label = getElementLabel(element) ?? role.replacingOccurrences(of: "AX", with: "")
                let confidence = calculateConfidence(for: type, bounds: bounds)

                return DetectedElement(
                    bounds: bounds,
                    label: label,
                    type: type,
                    confidence: confidence
                )
            }

            // Not a high-level element, try parent
            if let parent = getParentElement(element) {
                element = parent
            } else {
                break
            }
        }

        // Use FIRST reasonable non-screen-sized element we found
        // Only accept larger structural elements (panels, sidebars), skip small UI elements
        for elem in allElements {
            if elem.bounds.area < maxReasonableArea && elem.bounds.area >= 30000 {
                let type = mapRoleToElementType(elem.role)
                let label = getElementLabel(elem.element) ?? elem.role.replacingOccurrences(of: "AX", with: "")

                return DetectedElement(
                    bounds: elem.bounds,
                    label: label,
                    type: type,
                    confidence: 0.7
                )
            }
        }

        // Fallback 1: Prefer SMALLEST reasonable element
        if let candidate = smallestReasonableCandidate {
            let type = mapRoleToElementType(candidate.role)
            let label = getElementLabel(candidate.element) ?? candidate.role.replacingOccurrences(of: "AX", with: "")

            return DetectedElement(
                bounds: candidate.bounds,
                label: label,
                type: type,
                confidence: 0.6
            )
        }

        // Fallback 2: Use ANY element that's not screen-sized
        for elem in allElements {
            if elem.bounds.area < maxReasonableArea {
                let type = mapRoleToElementType(elem.role)
                let label = getElementLabel(elem.element) ?? elem.role.replacingOccurrences(of: "AX", with: "")

                return DetectedElement(
                    bounds: elem.bounds,
                    label: label,
                    type: type,
                    confidence: 0.4
                )
            }
        }

        return nil
    }

    private func getParentElement(_ element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXParentAttribute as CFString,
            &value
        )

        if result == .success, let parent = value {
            return (parent as! AXUIElement)
        }

        return nil
    }

    private func getElementChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &value
        )

        if result == .success, let children = value as? [AXUIElement] {
            return children
        }

        return nil
    }

    private func isHighLevelElement(_ role: String, bounds: CGRect) -> Bool {
        // Get screen size to filter out screen-sized elements
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let screenArea = screenSize.width * screenSize.height

        // Reject screen-sized or nearly-screen-sized elements
        if bounds.area > screenArea * 0.7 {
            return false
        }

        // Windows should be reasonably sized, not full screen
        if role == "AXWindow" {
            return bounds.width > 100 && bounds.height > 100 && bounds.area < screenArea * 0.7
        }

        // Only accept larger structural elements (panels, sidebars)
        // Skip small elements like individual messages or buttons
        let minWidth: CGFloat = 200
        let minHeight: CGFloat = 150
        let minArea: CGFloat = 30000

        return bounds.width >= minWidth &&
               bounds.height >= minHeight &&
               bounds.area >= minArea
    }

    public func getElementAt(point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?

        let result = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &element
        )

        if result == .success, let element = element {
            return element
        }

        return nil
    }

    public func getElementBounds(_ element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &value
        )

        guard result == .success, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        var position = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &position)

        value = nil
        let sizeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &value
        )

        guard sizeResult == .success, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        var size = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &size)

        return CGRect(origin: position, size: size)
    }

    public func getElementRole(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &value
        )

        if result == .success, let role = value as? String {
            return role
        }

        return nil
    }

    public func getElementLabel(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            element,
            kAXTitleAttribute as CFString,
            &value
        )

        if result == .success, let title = value as? String {
            return title
        }

        return nil
    }

    public func mapRoleToElementType(_ role: String) -> ElementType {
        if isSidebarRole(role) {
            return .sidebar
        }

        switch role {
        case "AXTextArea":
            return .codeEditor
        case "AXTextField":
            return .inputField
        case "AXButton":
            return .button
        case "AXGroup", "AXScrollArea":
            return .panel
        case "AXStaticText":
            return .textRegion
        default:
            return .other
        }
    }

    private func isSidebarRole(_ role: String) -> Bool {
        switch role {
        case "AXSplitGroup", "AXList", "AXOutline":
            return true
        default:
            return false
        }
    }

    private func isSidebarElement(_ element: AXUIElement, bounds: CGRect) -> Bool {
        // Find the screen that contains this element
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(centerPoint) } ?? NSScreen.main

        guard let screenSize = screen?.frame.size else {
            return false
        }

        // Get screen origin to calculate relative positions
        guard let screenOrigin = screen?.frame.origin else {
            return false
        }

        // Calculate relative position within the screen
        let relativeMinX = bounds.minX - screenOrigin.x
        let relativeMaxX = bounds.maxX - screenOrigin.x

        let isLeftEdge = relativeMinX < screenSize.width * 0.15
        let isRightEdge = relativeMaxX > screenSize.width * 0.85
        let isNarrow = bounds.width < screenSize.width * 0.3
        let isTall = bounds.height > screenSize.height * 0.5

        return (isLeftEdge || isRightEdge) && isNarrow && isTall
    }

    public func isAccessibilityEnabled() -> Bool {
        return AXIsProcessTrusted()
    }

    public func detectElement(around point: CGPoint) -> DetectedElement? {
        return findElement(at: point)
    }

    public func detectElementFast(at point: CGPoint) -> DetectedElement? {
        guard isAccessibilityEnabled() else {
            return nil
        }

        return findElement(at: point)
    }

    public func detectWindow(at point: CGPoint) -> DetectedElement? {
        guard isAccessibilityEnabled() else {
            return nil
        }

        // Try accessibility API first
        if var element = getElementAt(point: point) {
            var maxDepth = 15
            while maxDepth > 0 {
                maxDepth -= 1

                if let role = getElementRole(element), role == "AXWindow" {
                    guard let bounds = getElementBounds(element) else {
                        return nil
                    }

                    let label = getWindowLabel(element)

                    return DetectedElement(
                        bounds: bounds,
                        label: label,
                        type: .window,
                        confidence: 0.7
                    )
                }

                // Move to parent
                if let parent = getParentElement(element) {
                    element = parent
                } else {
                    break
                }
            }
        }

        // Fallback: Use CGWindowList to find window at point
        return detectWindowViaCGWindowList(at: point)
    }

    private func detectWindowViaCGWindowList(at point: CGPoint) -> DetectedElement? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            print("❌ CGWindowList failed")
            return nil
        }

        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let screenArea = screenSize.width * screenSize.height
        let maxReasonableArea = screenArea * 0.7

        var candidates: [(bounds: CGRect, label: String, area: CGFloat, layer: Int)] = []

        // CGWindowList is ordered front-to-back, so lower index = frontmost
        for (layer, windowInfo) in windowList.enumerated() {
            // Skip windows that are not on screen (minimized, hidden, etc.)
            if let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat, alpha < 0.1 {
                continue
            }

            // Skip IRIS overlay and system UI elements
            if let ownerName = windowInfo[kCGWindowOwnerName as String] as? String {
                if ownerName == "IRIS" || ownerName == "Dock" || ownerName == "Window Server" ||
                   ownerName == "WindowManager" || ownerName == "SystemUIServer" {
                    continue
                }
            }

            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }

            let bounds = CGRect(x: x, y: y, width: width, height: height)

            if bounds.contains(point) {
                // Skip menu bars and similar elements (very wide and short at top of screen)
                let aspectRatio = bounds.width / bounds.height
                let isAtTopOfScreen = bounds.origin.y < 100
                let isMenuBarLike = aspectRatio > 6.0 && bounds.height < 300 && isAtTopOfScreen

                if isMenuBarLike {
                    continue
                }

                // Skip full-screen windows
                let area = bounds.width * bounds.height
                if area > maxReasonableArea {
                    continue
                }

                let appName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
                let windowName = windowInfo[kCGWindowName as String] as? String
                let label = windowName ?? appName

                candidates.append((bounds: bounds, label: label, area: area, layer: layer))
            }
        }

        // Return the SMALLEST window from FRONTMOST windows (lower layer = closer to front)
        if let smallest = candidates.min(by: {
            if $0.layer != $1.layer {
                return $0.layer < $1.layer  // Prioritize frontmost
            }
            return $0.area < $1.area  // Then smallest
        }) {
            return DetectedElement(
                bounds: smallest.bounds,
                label: smallest.label,
                type: .window,
                confidence: 0.65
            )
        }

        return nil
    }

    private func getWindowLabel(_ element: AXUIElement) -> String {
        // Try to get window title
        if let title = getElementLabel(element), !title.isEmpty {
            return title
        }

        // Try to get application name via PID
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success {
            if let runningApp = NSRunningApplication(processIdentifier: pid) {
                return runningApp.localizedName ?? "Unknown Window"
            }
        }

        return "Window"
    }

    private func calculateConfidence(for type: ElementType, bounds: CGRect) -> Double {
        let area = bounds.width * bounds.height
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let screenArea = screenSize.width * screenSize.height

        // Larger elements tend to be more important
        let sizeConfidence = min(area / screenArea * 4.0, 0.8)

        // Role specificity confidence
        let roleConfidence = switch type {
        case .codeEditor: 0.9
        case .inputField: 0.85
        case .button: 0.8
        case .panel: 0.7
        case .sidebar: 0.75
        case .textRegion: 0.6
        case .window: 0.7
        case .other: 0.4
        }

        return (sizeConfidence + roleConfidence) / 2.0
    }
}
