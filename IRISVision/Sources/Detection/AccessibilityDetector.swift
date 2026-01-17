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
        guard var element = getElementAt(point: point) else {
            return nil
        }

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
                return nil
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

    private func isHighLevelElement(_ role: String, bounds: CGRect) -> Bool {
        // Allow sidebars, panels, windows, and large structural elements (excluding AXOutline and AXToolbar)
        let allowedRoles: Set<String> = [
            "AXSplitGroup",
            "AXList",
            "AXGroup",
            "AXScrollArea",
            "AXWindow"
        ]

        // Check if it's an allowed role
        guard allowedRoles.contains(role) else {
            return false
        }

        // Must be reasonably sized (not tiny UI elements)
        let minWidth: CGFloat = 150
        let minHeight: CGFloat = 150
        let minArea: CGFloat = 30000 // At least 200x150 equivalent

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
            print("⚠️  Accessibility NOT enabled")
            return nil
        }

        let element = findElement(at: point)
        if element == nil {
            if let axElement = getElementAt(point: point),
               let role = getElementRole(axElement),
               let bounds = getElementBounds(axElement) {
                let title = getElementLabel(axElement) ?? "no title"
                print("❌ Initial element: role=\(role) title=\"\(title)\" size=\(Int(bounds.width))x\(Int(bounds.height))")
            }
        } else {
            print("✅ Detected: \(element!.label) (\(element!.type)) role from AX")
        }
        return element
    }

    public func detectWindow(at point: CGPoint) -> DetectedElement? {
        guard isAccessibilityEnabled() else {
            print("❌ Window detection: Accessibility not enabled")
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
        print("🔍 Trying CGWindowList fallback for window detection")
        return detectWindowViaCGWindowList(at: point)
    }

    private func detectWindowViaCGWindowList(at point: CGPoint) -> DetectedElement? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            print("❌ CGWindowList failed")
            return nil
        }

        for windowInfo in windowList {
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
                    let msg = "⏭️ Skipping menu bar-like window: \(Int(bounds.width))x\(Int(bounds.height))"
                    print(msg)
                    try? msg.appendLine(to: "/tmp/iris_debug.log")
                    continue
                }

                let appName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
                let windowName = windowInfo[kCGWindowName as String] as? String

                let label = windowName ?? appName

                let msg = "✅ CGWindowList found: \(label) at bounds=(\(Int(bounds.origin.x)),\(Int(bounds.origin.y)) \(Int(bounds.width))x\(Int(bounds.height)))"
                print(msg)
                try? msg.appendLine(to: "/tmp/iris_debug.log")

                return DetectedElement(
                    bounds: bounds,
                    label: label,
                    type: .window,
                    confidence: 0.65
                )
            }
        }

        print("❌ No window found at point via CGWindowList")
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
