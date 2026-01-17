import Foundation
import CoreImage
import CoreGraphics
import AppKit

class ComputerVisionDetector {
    private let context = CIContext()

    func detectRegions(in image: CGImage, around gazePoint: CGPoint) -> [DetectedElement] {
        var detectedElements: [DetectedElement] = []

        // Analyze layout structure
        if let layoutRegions = analyzeLayout(in: image) {
            for region in layoutRegions {
                if let element = classifyLayoutRegion(region, imageSize: CGSize(width: image.width, height: image.height)) {
                    detectedElements.append(element)
                }
            }
        }

        // Detect panel-like structures
        if let panelElements = detectPanels(in: image, around: gazePoint) {
            detectedElements.append(contentsOf: panelElements)
        }

        return detectedElements
    }

    func analyzeLayout(in image: CGImage) -> [CGRect]? {
        let ciImage = CIImage(cgImage: image)

        // Apply edge detection
        let edges = ciImage.applyingFilter("CIEdges", parameters: ["inputIntensity": 5.0])

        // Apply threshold to get binary image
        let threshold = edges.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.5])

        // Get pixel data
        guard let pixelData = getPixelData(from: threshold, context: context) else {
            return nil
        }

        // Find rectangular regions in the edge-detected image
        let regions = findRectangularRegions(in: pixelData, imageSize: ciImage.extent.size)

        return regions
    }

    private func getPixelData(from image: CIImage, context: CIContext) -> [[Bool]]? {
        let extent = image.extent
        let width = Int(extent.width)
        let height = Int(extent.height)

        guard let cgImage = context.createCGImage(image, from: extent) else {
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow

        var pixelData = [UInt8](repeating: 0, count: totalBytes)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert to boolean grid (white pixels are edges)
        var boolGrid = [[Bool]](repeating: [Bool](repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]

                // Consider pixel as edge if it's bright
                boolGrid[y][x] = (Int(r) + Int(g) + Int(b)) > 128 * 3
            }
        }

        return boolGrid
    }

    private func findRectangularRegions(in pixelGrid: [[Bool]], imageSize: CGSize) -> [CGRect] {
        var regions: [CGRect] = []
        let height = pixelGrid.count
        let width = height > 0 ? pixelGrid[0].count : 0

        var visited = [[Bool]](repeating: [Bool](repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                if pixelGrid[y][x] && !visited[y][x] {
                    // Found an edge pixel, try to find rectangular region
                    if let rect = findRectangle(from: CGPoint(x: x, y: y), in: pixelGrid, visited: &visited) {
                        regions.append(rect)
                    }
                }
            }
        }

        // Filter and merge overlapping regions
        let filteredRegions = filterRegions(regions, imageSize: imageSize)

        return filteredRegions
    }

    private func findRectangle(from startPoint: CGPoint, in pixelGrid: [[Bool]], visited: inout [[Bool]]) -> CGRect? {
        let height = pixelGrid.count
        let width = height > 0 ? pixelGrid[0].count : 0

        var minX = Int(startPoint.x)
        var maxX = Int(startPoint.x)
        var minY = Int(startPoint.y)
        var maxY = Int(startPoint.y)

        // Simple flood fill to find connected edge pixels
        var stack = [CGPoint]()
        stack.append(startPoint)
        visited[Int(startPoint.y)][Int(startPoint.x)] = true

        while !stack.isEmpty {
            let point = stack.removeLast()
            let x = Int(point.x)
            let y = Int(point.y)

            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)

            // Check neighbors
            let neighbors = [
                CGPoint(x: x + 1, y: y),
                CGPoint(x: x - 1, y: y),
                CGPoint(x: x, y: y + 1),
                CGPoint(x: x, y: y - 1)
            ]

            for neighbor in neighbors {
                let nx = Int(neighbor.x)
                let ny = Int(neighbor.y)

                if nx >= 0 && nx < width && ny >= 0 && ny < height &&
                   pixelGrid[ny][nx] && !visited[ny][nx] {
                    visited[ny][nx] = true
                    stack.append(neighbor)
                }
            }
        }

        let rectWidth = maxX - minX + 1
        let rectHeight = maxY - minY + 1

        // Filter out very small or very large regions
        if rectWidth < 50 || rectHeight < 50 || rectWidth > Int(Double(width) * 0.8) || rectHeight > Int(Double(height) * 0.8) {
            return nil
        }

        return CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: CGFloat(minY) / CGFloat(height),
            width: CGFloat(rectWidth) / CGFloat(width),
            height: CGFloat(rectHeight) / CGFloat(height)
        )
    }

    private func filterRegions(_ regions: [CGRect], imageSize: CGSize) -> [CGRect] {
        var filtered: [CGRect] = []

        for region in regions {
            // Convert to absolute coordinates for easier processing
            let absRegion = CGRect(
                x: region.origin.x * imageSize.width,
                y: region.origin.y * imageSize.height,
                width: region.width * imageSize.width,
                height: region.height * imageSize.height
            )

            // Skip regions that are too small or too close to edges
            if absRegion.width < 100 || absRegion.height < 100 {
                continue
            }

            // Check if this region overlaps significantly with existing regions
            var overlaps = false
            for existing in filtered {
                let absExisting = CGRect(
                    x: existing.origin.x * imageSize.width,
                    y: existing.origin.y * imageSize.height,
                    width: existing.width * imageSize.width,
                    height: existing.height * imageSize.height
                )

                let intersection = absRegion.intersection(absExisting)
                let overlapRatio = (intersection.width * intersection.height) /
                                 (absRegion.width * absRegion.height)

                if overlapRatio > 0.5 {
                    overlaps = true
                    break
                }
            }

            if !overlaps {
                filtered.append(region)
            }
        }

        return filtered
    }

    private func classifyLayoutRegion(_ region: CGRect, imageSize: CGSize) -> DetectedElement? {
        let absRegion = CGRect(
            x: region.origin.x * imageSize.width,
            y: region.origin.y * imageSize.height,
            width: region.width * imageSize.width,
            height: region.height * imageSize.height
        )

        // Classify based on position and size
        let screenWidth = imageSize.width
        let screenHeight = imageSize.height

        // Check if it's a sidebar (narrow, tall, at edge)
        let isSidebar = (absRegion.width / screenWidth < 0.3) &&
                       (absRegion.height / screenHeight > 0.6) &&
                       ((absRegion.minX < screenWidth * 0.1) || (absRegion.maxX > screenWidth * 0.9))

        if isSidebar {
            return DetectedElement(
                bounds: absRegion,
                label: "Sidebar",
                type: .sidebar,
                confidence: 0.7
            )
        }

        // Check if it's a panel (medium size, not at edge)
        let isPanel = (absRegion.width / screenWidth > 0.2) &&
                     (absRegion.width / screenWidth < 0.8) &&
                     (absRegion.height / screenHeight > 0.2) &&
                     (absRegion.height / screenHeight < 0.8)

        if isPanel {
            return DetectedElement(
                bounds: absRegion,
                label: "Panel",
                type: .panel,
                confidence: 0.6
            )
        }

        return nil
    }

    private func detectPanels(in image: CGImage, around gazePoint: CGPoint) -> [DetectedElement]? {
        let ciImage = CIImage(cgImage: image)

        // Use CIEdgeWork filter for better panel detection
        let edgeWork = ciImage.applyingFilter("CIEdgeWork", parameters: ["inputRadius": 3.0])

        // Convert to grayscale
        let grayscale = edgeWork.applyingFilter("CIPhotoEffectMono")

        // Apply threshold
        let threshold = grayscale.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.3])

        // Get pixel data and find potential panel regions
        guard let pixelData = getPixelData(from: threshold, context: context) else {
            return nil
        }

        let regions = findPotentialPanels(in: pixelData, imageSize: ciImage.extent.size)

        return regions.compactMap { region in
            classifyLayoutRegion(region, imageSize: ciImage.extent.size)
        }
    }

    private func findPotentialPanels(in pixelGrid: [[Bool]], imageSize: CGSize) -> [CGRect] {
        var panels: [CGRect] = []
        let height = pixelGrid.count
        let width = height > 0 ? pixelGrid[0].count : 0

        // Look for large rectangular areas that might be panels
        let stepSize = 50 // Check every 50 pixels

        for y in stride(from: 0, to: height - stepSize, by: stepSize) {
            for x in stride(from: 0, to: width - stepSize, by: stepSize) {
                if let panel = detectPanelAt(x: x, y: y, in: pixelGrid, stepSize: stepSize) {
                    panels.append(panel)
                }
            }
        }

        return mergeOverlappingPanels(panels)
    }

    private func detectPanelAt(x: Int, y: Int, in pixelGrid: [[Bool]], stepSize: Int) -> CGRect? {
        let height = pixelGrid.count
        let width = height > 0 ? pixelGrid[0].count : 0

        // Look for a rectangular region with edges
        var hasTopEdge = false
        var hasBottomEdge = false
        var hasLeftEdge = false
        var hasRightEdge = false

        // Check top edge
        for i in x..<(x + stepSize) {
            if i < width && pixelGrid[y][i] {
                hasTopEdge = true
                break
            }
        }

        // Check bottom edge
        for i in x..<(x + stepSize) {
            if i < width && y + stepSize < height && pixelGrid[y + stepSize][i] {
                hasBottomEdge = true
                break
            }
        }

        // Check left edge
        for i in y..<(y + stepSize) {
            if i < height && pixelGrid[i][x] {
                hasLeftEdge = true
                break
            }
        }

        // Check right edge
        for i in y..<(y + stepSize) {
            if i < height && x + stepSize < width && pixelGrid[i][x + stepSize] {
                hasRightEdge = true
                break
            }
        }

        if hasTopEdge && hasBottomEdge && hasLeftEdge && hasRightEdge {
            return CGRect(
                x: CGFloat(x),
                y: CGFloat(y),
                width: CGFloat(stepSize),
                height: CGFloat(stepSize)
            )
        }

        return nil
    }

    private func mergeOverlappingPanels(_ panels: [CGRect]) -> [CGRect] {
        var merged = [CGRect]()

        for panel in panels {
            var mergedWithExisting = false

            for (index, existing) in merged.enumerated() {
                if panel.intersects(existing) || panel.distance(to: existing) < 100 {
                    // Merge the panels
                    let union = panel.union(existing)
                    merged[index] = union
                    mergedWithExisting = true
                    break
                }
            }

            if !mergedWithExisting {
                merged.append(panel)
            }
        }

        return merged
    }
}

extension CGRect {
    func distance(to other: CGRect) -> CGFloat {
        if self.intersects(other) {
            return 0
        }

        let dx = max(self.minX - other.maxX, other.minX - self.maxX, 0)
        let dy = max(self.minY - other.maxY, other.minY - self.maxY, 0)

        return sqrt(dx * dx + dy * dy)
    }
}