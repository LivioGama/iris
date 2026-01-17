import Foundation
import CoreGraphics
import AppKit
import IRISCore
import IRISVision

public class ContextualAnalysisService {
    public init() {}

    private let accessibilityDetector = AccessibilityDetector()
    private let visionTextDetector = VisionTextDetector()
    private let computerVisionDetector = ComputerVisionDetector()

    private var lastAnalysisTime: Date?
    private let analysisThrottleInterval: TimeInterval = 0.2 // 200ms between analyses for near-instant response
    private var analysisInProgress = false
    private var lastAnalysisPoint: CGPoint?
    private let minDistanceForReanalysis: CGFloat = 200.0 // pixels - increased to reduce redundant analysis

    // Queue for pending analysis requests
    private var pendingRequests: [(point: CGPoint, image: CGImage)] = []
    private let queueLock = NSLock()

    public func analyzeContext(around gazePoint: CGPoint, screenImage: CGImage) async -> DetectedElement? {
        // If analysis is in progress, queue this request
        queueLock.lock()
        if analysisInProgress {
            pendingRequests.append((point: gazePoint, image: screenImage))
            queueLock.unlock()
            return nil
        }

        // Check if we should skip this analysis
        if shouldSkipAnalysis(for: gazePoint) {
            queueLock.unlock()
            return nil
        }

        analysisInProgress = true
        lastAnalysisTime = Date()
        lastAnalysisPoint = gazePoint
        queueLock.unlock()

        // Perform the analysis
        let result = await performAnalysis(gazePoint: gazePoint, screenImage: screenImage)

        // Mark analysis as complete and process any queued requests
        queueLock.lock()
        analysisInProgress = false

        // Process the most recent queued request (discard older ones)
        if let latestRequest = pendingRequests.last {
            pendingRequests.removeAll() // Clear all pending requests
            queueLock.unlock()

            // Process the latest request
            Task {
                _ = await self.analyzeContext(around: latestRequest.point, screenImage: latestRequest.image)
            }
        } else {
            queueLock.unlock()
        }

        return result
    }

    private func shouldSkipAnalysis(for gazePoint: CGPoint) -> Bool {
        // Throttle analysis to avoid excessive API calls
        if let lastTime = lastAnalysisTime, Date().timeIntervalSince(lastTime) < analysisThrottleInterval {
            return true
        }

        // Skip analysis if gaze point hasn't moved significantly
        if let lastPoint = lastAnalysisPoint {
            let distance = hypot(gazePoint.x - lastPoint.x, gazePoint.y - lastPoint.y)
            if distance < minDistanceForReanalysis {
                return true
            }
        }

        return false
    }

    private func performAnalysis(gazePoint: CGPoint, screenImage: CGImage) async -> DetectedElement? {
        let msg = "🔎 Analysis at (\(Int(gazePoint.x)), \(Int(gazePoint.y)))"
        print(msg)
        try? msg.appendLine(to: "/tmp/iris_debug.log")

        var allDetections: [DetectedElement] = []
        var sidebarDetections: [DetectedElement] = []

        if accessibilityDetector.isAccessibilityEnabled(),
           let accessibilityElement = accessibilityDetector.detectElement(around: gazePoint) {
            let msg2 = "📍 Accessibility found: \(accessibilityElement.label)"
            print(msg2)
            try? msg2.appendLine(to: "/tmp/iris_debug.log")
            if accessibilityElement.type == .sidebar {
                sidebarDetections.append(accessibilityElement)
            } else {
                allDetections.append(accessibilityElement)
            }
        } else {
            let msg2 = "📍 No accessibility element"
            print(msg2)
            try? msg2.appendLine(to: "/tmp/iris_debug.log")
        }

        if allDetections.isEmpty {
            let visionElements = await visionTextDetector.detectTextRegions(in: screenImage, around: gazePoint)
            for element in visionElements {
                if element.type == .sidebar {
                    sidebarDetections.append(element)
                } else {
                    allDetections.append(element)
                }
            }
        }

        if allDetections.isEmpty {
            let layoutElements = computerVisionDetector.detectRegions(in: screenImage, around: gazePoint)
            for element in layoutElements {
                if element.type == .sidebar {
                    sidebarDetections.append(element)
                } else {
                    allDetections.append(element)
                }
            }
        }

        // First try to find a specific element from all detections
        if let selected = combineDetections(allDetections, gazePoint: gazePoint) {
            return selected
        }

        // Then try sidebars
        if let sidebar = sidebarDetections.first(where: { $0.bounds.contains(gazePoint) }) {
            return sidebar
        }

        // If no specific element was found, escalate to window-level detection
        // This ensures we always provide at least window-level context
        let msg3 = "🔍 Escalating to window detection..."
        print(msg3)
        try? msg3.appendLine(to: "/tmp/iris_debug.log")

        if let windowElement = accessibilityDetector.detectWindow(at: gazePoint) {
            let msg4 = "🪟 Window escalation: \(windowElement.label)"
            print(msg4)
            try? msg4.appendLine(to: "/tmp/iris_debug.log")
            return windowElement
        }

        let msg5 = "⚠️ No detection at all - not even window!"
        print(msg5)
        try? msg5.appendLine(to: "/tmp/iris_debug.log")
        return nil
    }

    private func combineDetections(_ detections: [DetectedElement], gazePoint: CGPoint) -> DetectedElement? {
        guard !detections.isEmpty else { return nil }

        let relevantDetections = detections.filter { detection in
            detection.bounds.contains(gazePoint)
        }

        if relevantDetections.isEmpty {
            return findClosestDetection(to: gazePoint, from: detections)
        }

        let sortedDetections = relevantDetections.sorted { (a, b) -> Bool in
            let aDistance = distance(from: gazePoint, to: a.bounds.center)
            let bDistance = distance(from: gazePoint, to: b.bounds.center)

            if abs(a.confidence - b.confidence) > 0.1 {
                return a.confidence > b.confidence
            }
            return aDistance < bDistance
        }

        return sortedDetections.first
    }

    private func findClosestDetection(to gazePoint: CGPoint, from detections: [DetectedElement]) -> DetectedElement? {
        guard !detections.isEmpty else { return nil }

        var closestDetection: DetectedElement?
        var closestDistance: CGFloat = .greatestFiniteMagnitude

        for detection in detections {
            let center = detection.bounds.center
            let distance = hypot(gazePoint.x - center.x, gazePoint.y - center.y)

            if distance < closestDistance {
                closestDistance = distance
                closestDetection = detection
            }
        }

        // Only return if the detection is reasonably close (within 200 pixels)
        if closestDistance < 200 {
            return closestDetection
        }

        return nil
    }

    private func distance(from point: CGPoint, to center: CGPoint) -> CGFloat {
        return hypot(point.x - center.x, point.y - center.y)
    }
}

extension CGRect {
    public var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}
