import XCTest
@testable import IRISVision
@testable import IRISCore

final class ElementDetectionIntegrationTests: XCTestCase {

    // MARK: - Element Detection Accuracy Tests

    func testAccessibilityDetectorInitialization() {
        let detector = AccessibilityDetector()
        XCTAssertNotNil(detector)
    }

    func testComputerVisionDetectorInitialization() {
        let detector = ComputerVisionDetector()
        XCTAssertNotNil(detector)
    }

    func testContextualAnalysisServiceInitialization() {
        let service = ContextualAnalysisService()
        XCTAssertNotNil(service)
    }

    func testVisionTextDetectorInitialization() {
        let detector = VisionTextDetector()
        XCTAssertNotNil(detector)
    }

    // MARK: - DetectedElement Model Tests

    func testDetectedElementCreation() {
        let element = DetectedElement(
            bounds: NSRect(x: 100, y: 100, width: 200, height: 50),
            label: "Submit Button",
            type: .button,
            confidence: 0.95
        )

        XCTAssertEqual(element.bounds.origin.x, 100)
        XCTAssertEqual(element.bounds.origin.y, 100)
        XCTAssertEqual(element.bounds.width, 200)
        XCTAssertEqual(element.bounds.height, 50)
        XCTAssertEqual(element.label, "Submit Button")
        XCTAssertEqual(element.type, .button)
        XCTAssertEqual(element.confidence, 0.95)
    }

    func testDetectedElementWithDifferentTypes() {
        let types: [ElementType] = [.button, .inputField, .textRegion, .panel, .sidebar, .window, .codeEditor, .other]

        for type in types {
            let element = DetectedElement(
                bounds: NSRect(x: 0, y: 0, width: 100, height: 100),
                label: "Test element",
                type: type,
                confidence: 0.9
            )

            XCTAssertEqual(element.type, type)
        }
    }

    func testDetectedElementConfidenceLevels() {
        let confidenceLevels: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for confidence in confidenceLevels {
            let element = DetectedElement(
                bounds: NSRect.zero,
                label: "Test",
                type: .button,
                confidence: confidence
            )

            XCTAssertEqual(element.confidence, confidence)
        }
    }

    // MARK: - Element Detection Workflow Tests

    func testMultipleDetectorIntegration() {
        let accessibilityDetector = AccessibilityDetector()
        let visionDetector = ComputerVisionDetector()
        let textDetector = VisionTextDetector()

        XCTAssertNotNil(accessibilityDetector)
        XCTAssertNotNil(visionDetector)
        XCTAssertNotNil(textDetector)
    }

    func testDetectedElementArrayOperations() {
        var elements: [DetectedElement] = []

        // Add elements
        for i in 1...5 {
            let element = DetectedElement(
                bounds: NSRect(x: Double(i * 100), y: 100, width: 80, height: 30),
                label: "Button \(i)",
                type: .button,
                confidence: 0.9
            )
            elements.append(element)
        }

        XCTAssertEqual(elements.count, 5)

        // Filter by confidence
        let highConfidenceElements = elements.filter { $0.confidence >= 0.9 }
        XCTAssertEqual(highConfidenceElements.count, 5)

        // Filter by type
        let buttons = elements.filter { $0.type == .button }
        XCTAssertEqual(buttons.count, 5)
    }

    func testElementSortingByConfidence() {
        let elements = [
            DetectedElement(bounds: .zero, label: "Low", type: .button, confidence: 0.5),
            DetectedElement(bounds: .zero, label: "High", type: .button, confidence: 0.95),
            DetectedElement(bounds: .zero, label: "Medium", type: .button, confidence: 0.75)
        ]

        let sorted = elements.sorted { $0.confidence > $1.confidence }

        XCTAssertEqual(sorted[0].label, "High")
        XCTAssertEqual(sorted[1].label, "Medium")
        XCTAssertEqual(sorted[2].label, "Low")
    }

    func testElementFilteringByBounds() {
        let elements = [
            DetectedElement(bounds: NSRect(x: 0, y: 0, width: 100, height: 50), label: "Small", type: .button, confidence: 0.9),
            DetectedElement(bounds: NSRect(x: 0, y: 0, width: 500, height: 300), label: "Large", type: .button, confidence: 0.9)
        ]

        // Filter elements larger than 200x100
        let largeElements = elements.filter { $0.bounds.width > 200 && $0.bounds.height > 100 }

        XCTAssertEqual(largeElements.count, 1)
        XCTAssertEqual(largeElements[0].label, "Large")
    }

    // MARK: - Screen Region Detection Tests

    func testElementsInScreenRegions() {
        // Simulate screen divided into quadrants
        let screenSize = NSSize(width: 1920, height: 1080)
        let halfWidth = screenSize.width / 2
        let halfHeight = screenSize.height / 2

        let topLeft = DetectedElement(
            bounds: NSRect(x: 100, y: 100, width: 100, height: 50),
            label: "Top Left",
            type: .button,
            confidence: 0.9
        )

        let topRight = DetectedElement(
            bounds: NSRect(x: halfWidth + 100, y: 100, width: 100, height: 50),
            label: "Top Right",
            type: .button,
            confidence: 0.9
        )

        let bottomLeft = DetectedElement(
            bounds: NSRect(x: 100, y: halfHeight + 100, width: 100, height: 50),
            label: "Bottom Left",
            type: .button,
            confidence: 0.9
        )

        let bottomRight = DetectedElement(
            bounds: NSRect(x: halfWidth + 100, y: halfHeight + 100, width: 100, height: 50),
            label: "Bottom Right",
            type: .button,
            confidence: 0.9
        )

        let elements = [topLeft, topRight, bottomLeft, bottomRight]

        // Test quadrant detection
        let leftElements = elements.filter { $0.bounds.origin.x < halfWidth }
        XCTAssertEqual(leftElements.count, 2)

        let rightElements = elements.filter { $0.bounds.origin.x >= halfWidth }
        XCTAssertEqual(rightElements.count, 2)

        let topElements = elements.filter { $0.bounds.origin.y < halfHeight }
        XCTAssertEqual(topElements.count, 2)

        let bottomElements = elements.filter { $0.bounds.origin.y >= halfHeight }
        XCTAssertEqual(bottomElements.count, 2)
    }

    // MARK: - Element Overlap Detection Tests

    func testElementOverlapDetection() {
        let element1 = DetectedElement(
            bounds: NSRect(x: 100, y: 100, width: 200, height: 100),
            label: "Element 1",
            type: .button,
            confidence: 0.9
        )

        let element2 = DetectedElement(
            bounds: NSRect(x: 150, y: 150, width: 200, height: 100),
            label: "Element 2",
            type: .button,
            confidence: 0.9
        )

        // Check if elements overlap
        let intersects = element1.bounds.intersects(element2.bounds)
        XCTAssertTrue(intersects)
    }

    func testNonOverlappingElements() {
        let element1 = DetectedElement(
            bounds: NSRect(x: 0, y: 0, width: 100, height: 100),
            label: "Element 1",
            type: .button,
            confidence: 0.9
        )

        let element2 = DetectedElement(
            bounds: NSRect(x: 200, y: 200, width: 100, height: 100),
            label: "Element 2",
            type: .button,
            confidence: 0.9
        )

        // Check if elements don't overlap
        let intersects = element1.bounds.intersects(element2.bounds)
        XCTAssertFalse(intersects)
    }

    // MARK: - Element Distance Calculation Tests

    func testElementDistanceCalculation() {
        let element1 = DetectedElement(
            bounds: NSRect(x: 0, y: 0, width: 100, height: 100),
            label: "Element 1",
            type: .button,
            confidence: 0.9
        )

        let element2 = DetectedElement(
            bounds: NSRect(x: 300, y: 400, width: 100, height: 100),
            label: "Element 2",
            type: .button,
            confidence: 0.9
        )

        let center1 = NSPoint(
            x: element1.bounds.midX,
            y: element1.bounds.midY
        )

        let center2 = NSPoint(
            x: element2.bounds.midX,
            y: element2.bounds.midY
        )

        let dx = center2.x - center1.x
        let dy = center2.y - center1.y
        let distance = sqrt(dx * dx + dy * dy)

        XCTAssertGreaterThan(distance, 0)
    }

    // MARK: - Element Type Distribution Tests

    func testElementTypeDistribution() {
        let elements = [
            DetectedElement(bounds: .zero, label: "Button 1", type: .button, confidence: 0.9),
            DetectedElement(bounds: .zero, label: "Button 2", type: .button, confidence: 0.9),
            DetectedElement(bounds: .zero, label: "Text 1", type: .inputField, confidence: 0.9),
            DetectedElement(bounds: .zero, label: "Label 1", type: .textRegion, confidence: 0.9),
            DetectedElement(bounds: .zero, label: "Panel 1", type: .panel, confidence: 0.9)
        ]

        // Count by type
        let buttonCount = elements.filter { $0.type == .button }.count
        let inputFieldCount = elements.filter { $0.type == .inputField }.count
        let textRegionCount = elements.filter { $0.type == .textRegion }.count
        let panelCount = elements.filter { $0.type == .panel }.count

        XCTAssertEqual(buttonCount, 2)
        XCTAssertEqual(inputFieldCount, 1)
        XCTAssertEqual(textRegionCount, 1)
        XCTAssertEqual(panelCount, 1)
    }

    // MARK: - Performance Tests

    func testElementArrayPerformance() {
        // Create a large array of elements
        var elements: [DetectedElement] = []
        let types: [ElementType] = [.button, .inputField, .textRegion]

        for i in 0..<1000 {
            let element = DetectedElement(
                bounds: NSRect(x: Double(i % 100) * 10, y: Double(i / 100) * 10, width: 8, height: 8),
                label: "Element \(i)",
                type: types[i % types.count],
                confidence: Double.random(in: 0.7...1.0)
            )
            elements.append(element)
        }

        XCTAssertEqual(elements.count, 1000)

        // Test filtering performance
        let startTime = Date()
        let highConfidence = elements.filter { $0.confidence > 0.9 }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThan(highConfidence.count, 0)
        XCTAssertLessThan(duration, 0.1)  // Should complete in less than 100ms
    }

    // MARK: - Memory Management Tests

    func testDetectorDeallocation() {
        weak var weakDetector: AccessibilityDetector?

        autoreleasepool {
            let detector = AccessibilityDetector()
            weakDetector = detector
        }

        XCTAssertNil(weakDetector)
    }
}
