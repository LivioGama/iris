import Foundation
import Vision
import CoreGraphics
import AppKit
import IRISCore

public class VisionTextDetector {
    private let textRecognitionRequest: VNRecognizeTextRequest

    public init() {
        textRecognitionRequest = VNRecognizeTextRequest()
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = false
        textRecognitionRequest.recognitionLanguages = ["en-US"]
    }

    /// Extract individual messages from a screenshot using Vision framework
    /// Returns an array of message texts, separated by visual layout (line breaks, spacing)
    /// - Parameters:
    ///   - image: The image to extract messages from
    ///   - skipLeftSidebar: If true, ignores text in the left 35% of the image (useful for chat apps with contact lists)
    public func extractMessages(from image: CGImage, skipLeftSidebar: Bool = true) async -> [String] {
        print("📨 VisionTextDetector: Extracting messages from image (skipLeftSidebar: \(skipLeftSidebar))")
        let handler = VNImageRequestHandler(cgImage: image)

        do {
            try handler.perform([textRecognitionRequest])

            guard let results = textRecognitionRequest.results else {
                print("📨 VisionTextDetector: No text observations found")
                return []
            }

            print("📨 VisionTextDetector: Found \(results.count) text observations")

            // Debug: Show X positions of ALL text sorted by X coordinate
            print("📊 All text sorted by X-coordinate:")
            let sorted = results.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            for obs in sorted {
                if let text = obs.topCandidates(1).first?.string {
                    print("   📍 x=\(String(format: "%.2f", obs.boundingBox.minX)) '\(text.prefix(30))'")
                }
            }

            // Filter out sidebar if requested
            let filteredResults: [VNRecognizedTextObservation]
            if skipLeftSidebar {
                // For Telegram: sidebar extends to about x=0.72
                // Chat messages and UI are beyond x > 0.72
                // Use threshold that captures message area but not just UI buttons
                filteredResults = results.filter { $0.boundingBox.minX > 0.72 }
                print("📨 VisionTextDetector: After filtering sidebar (>0.72): \(filteredResults.count) observations")

                // Debug: show what we're KEEPING (actual messages)
                print("📨 Messages being analyzed (x > 0.72):")
                for obs in filteredResults.prefix(10) {
                    if let text = obs.topCandidates(1).first?.string {
                        print("   ✅ KEPT: '\(text)' at x=\(String(format: "%.2f", obs.boundingBox.minX))")
                    }
                }
            } else {
                filteredResults = results
            }

            // Group observations by vertical proximity to separate messages
            let messages = groupIntoMessages(filteredResults)
            print("📨 VisionTextDetector: Grouped into \(messages.count) messages")

            return messages
        } catch {
            print("📨 VisionTextDetector: Error extracting messages: \(error)")
            return []
        }
    }

    /// Groups text observations into individual messages based on vertical spacing
    private func groupIntoMessages(_ observations: [VNRecognizedTextObservation]) -> [String] {
        // Sort observations from top to bottom (Vision uses bottom-left origin, so sort by descending Y)
        let sorted = observations.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }

        var messages: [String] = []
        var currentMessageLines: [String] = []
        var previousY: CGFloat? = nil

        for observation in sorted {
            guard let text = observation.topCandidates(1).first?.string else { continue }

            let currentY = observation.boundingBox.maxY
            let lineHeight = observation.boundingBox.height

            // If there's a significant vertical gap, start a new message
            // Threshold: gap > 2x line height = new message
            if let prevY = previousY {
                let gap = prevY - currentY
                if gap > lineHeight * 2.0 {
                    // Save current message and start new one
                    if !currentMessageLines.isEmpty {
                        messages.append(currentMessageLines.joined(separator: " "))
                        currentMessageLines = []
                    }
                }
            }

            currentMessageLines.append(text)
            previousY = currentY
        }

        // Don't forget the last message
        if !currentMessageLines.isEmpty {
            messages.append(currentMessageLines.joined(separator: " "))
        }

        return messages
    }

    public func detectTextRegions(in image: CGImage, around gazePoint: CGPoint) async -> [DetectedElement] {
        print("🔤 Vision: Starting text detection on \(image.width)x\(image.height) image")
        let handler = VNImageRequestHandler(cgImage: image)

        do {
            try handler.perform([textRecognitionRequest])

            guard let results = textRecognitionRequest.results else {
                print("🔤 Vision: No results from text recognition")
                return []
            }

            print("🔤 Vision: Found \(results.count) text observations")
            let processed = processTextObservations(results, gazePoint: gazePoint)
            print("🔤 Vision: Processed into \(processed.count) detected elements")
            return processed
        } catch {
            print("🔤 Vision: Text detection failed: \(error)")
            return []
        }
    }

    private func processTextObservations(_ observations: [VNRecognizedTextObservation], gazePoint: CGPoint) -> [DetectedElement] {
        // Group observations into logical text regions
        let groupedRegions = groupObservationsByProximity(observations)

        var detectedElements: [DetectedElement] = []

        for region in groupedRegions {
            if let element = classifyTextRegion(region, gazePoint: gazePoint) {
                detectedElements.append(element)
            }
        }

        return detectedElements
    }

    private func groupObservationsByProximity(_ observations: [VNRecognizedTextObservation]) -> [[VNRecognizedTextObservation]] {
        var groups: [[VNRecognizedTextObservation]] = []
        var processed = Set<VNRecognizedTextObservation>()

        for observation in observations {
            if processed.contains(observation) { continue }

            var group = [observation]
            processed.insert(observation)

            // Find nearby observations to group together
            for other in observations {
                if processed.contains(other) { continue }

                let distance = distanceBetween(observation, other)
                if distance < 50 { // Group if within 50 points
                    group.append(other)
                    processed.insert(other)
                }
            }

            groups.append(group)
        }

        return groups
    }

    private func distanceBetween(_ obs1: VNRecognizedTextObservation, _ obs2: VNRecognizedTextObservation) -> CGFloat {
        let center1 = CGPoint(
            x: obs1.boundingBox.midX,
            y: obs1.boundingBox.midY
        )
        let center2 = CGPoint(
            x: obs2.boundingBox.midX,
            y: obs2.boundingBox.midY
        )

        return hypot(center1.x - center2.x, center1.y - center2.y)
    }

    private func classifyTextRegion(_ observations: [VNRecognizedTextObservation], gazePoint: CGPoint) -> DetectedElement? {
        guard !observations.isEmpty else { return nil }

        // Calculate bounding box for the entire region
        let bounds = calculateRegionBounds(observations)

        // Extract text content
        let textContent = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }.joined(separator: " ")

        // Analyze text characteristics
        let characteristics = analyzeTextCharacteristics(observations, text: textContent)

        // Determine element type based on characteristics
        let type = classifyType(from: characteristics)

        // Calculate confidence
        let confidence = calculateTextConfidence(characteristics, type: type)

        // Create label
        let label = createLabel(for: type, text: textContent)

        return DetectedElement(
            bounds: bounds,
            label: label,
            type: type,
            confidence: confidence
        )
    }

    private func calculateRegionBounds(_ observations: [VNRecognizedTextObservation]) -> CGRect {
        guard let first = observations.first else { return .zero }

        var minX = first.boundingBox.minX
        var minY = first.boundingBox.minY
        var maxX = first.boundingBox.maxX
        var maxY = first.boundingBox.maxY

        for observation in observations {
            minX = min(minX, observation.boundingBox.minX)
            minY = min(minY, observation.boundingBox.minY)
            maxX = max(maxX, observation.boundingBox.maxX)
            maxY = max(maxY, observation.boundingBox.maxY)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func analyzeTextCharacteristics(_ observations: [VNRecognizedTextObservation], text: String) -> TextCharacteristics {
        let lineCount = observations.count
        let averageHeight = observations.map { $0.boundingBox.height }.reduce(0, +) / CGFloat(observations.count)
        let hasIndentation = text.contains("    ") || text.contains("\t")
        let wordCount = text.split(separator: " ").count
        let averageWordsPerLine = Double(wordCount) / Double(lineCount)

        // Check for monospace-like characteristics
        let isUniformWidth = checkUniformCharacterWidth(observations)

        // Check for code-like patterns
        let hasCodePatterns = text.contains("{") || text.contains("}") ||
                             text.contains("func") || text.contains("class") ||
                             text.contains("import") || text.contains("let") ||
                             text.contains("var")

        return TextCharacteristics(
            lineCount: lineCount,
            averageHeight: averageHeight,
            hasIndentation: hasIndentation,
            averageWordsPerLine: averageWordsPerLine,
            isUniformWidth: isUniformWidth,
            hasCodePatterns: hasCodePatterns
        )
    }

    private func checkUniformCharacterWidth(_ observations: [VNRecognizedTextObservation]) -> Bool {
        // Simple heuristic: check if character heights are relatively uniform
        guard observations.count >= 3 else { return false }

        let heights = observations.map { $0.boundingBox.height }
        let avgHeight = heights.reduce(0, +) / CGFloat(heights.count)
        let variance = heights.map { pow($0 - avgHeight, 2) }.reduce(0, +) / CGFloat(heights.count)
        let standardDeviation = sqrt(variance)

        // If standard deviation is less than 10% of average, consider uniform
        return standardDeviation / avgHeight < 0.1
    }

    private func classifyType(from characteristics: TextCharacteristics) -> IRISCore.ElementType {
        if characteristics.lineCount == 1 && characteristics.averageHeight < 0.02 {
            return .inputField
        }

        if characteristics.hasCodePatterns && characteristics.hasIndentation {
            return .codeEditor
        }

        if characteristics.isUniformWidth && characteristics.lineCount > 3 {
            return .codeEditor
        }

        if characteristics.lineCount > 2 {
            return .textRegion
        }

        return .other
    }

    private func calculateTextConfidence(_ characteristics: TextCharacteristics, type: IRISCore.ElementType) -> Double {
        switch type {
        case .codeEditor:
            var confidence = 0.6
            if characteristics.hasCodePatterns { confidence += 0.2 }
            if characteristics.hasIndentation { confidence += 0.1 }
            if characteristics.isUniformWidth { confidence += 0.1 }
            return min(confidence, 0.95)

        case .inputField:
            return characteristics.lineCount == 1 ? 0.8 : 0.4

        case .textRegion:
            return min(0.7, Double(characteristics.lineCount) / 10.0 + 0.3)

        default:
            return 0.4
        }
    }

    private func createLabel(for type: IRISCore.ElementType, text: String) -> String {
        switch type {
        case .codeEditor:
            return "Code Editor"
        case .inputField:
            return "Input Field"
        case .textRegion:
            return "Text"
        default:
            return "Text Element"
        }
    }
}

public struct TextCharacteristics {
    public let lineCount: Int
    public let averageHeight: CGFloat
    public let hasIndentation: Bool
    public let averageWordsPerLine: Double
    public let isUniformWidth: Bool
    public let hasCodePatterns: Bool
}
