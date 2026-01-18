import Foundation
import AppKit
import IRISCore
import ScreenCaptureKit

/// Manages screen capture and image processing
/// Responsibility: Screenshot capture and image manipulation
public class ScreenshotService {
    public init() {}

    /// Captures a screenshot of the screen where the mouse cursor is located
    /// - Returns: NSImage of the captured screen, or nil if capture fails
    public func captureCurrentScreen() -> NSImage? {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main

        guard let screen = screen else {
            print("❌ ScreenshotService: No screen found")
            return nil
        }

        return captureScreen(screen)
    }

    /// Captures a screenshot of a specific screen
    /// - Parameter screen: The NSScreen to capture
    /// - Returns: NSImage of the captured screen, or nil if capture fails
    public func captureScreen(_ screen: NSScreen) -> NSImage? {
        // Use ScreenCaptureKit on macOS 14+ for proper screen capture
        if #available(macOS 14.0, *) {
            return captureScreenWithSCK(screen)
        } else {
            return captureScreenLegacy(screen)
        }
    }

    /// Modern screen capture using ScreenCaptureKit (macOS 14+)
    @available(macOS 14.0, *)
    private func captureScreenWithSCK(_ screen: NSScreen) -> NSImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var capturedImage: NSImage?

        Task {
            do {
                let content = try await SCShareableContent.current

                // Find the matching SCDisplay by displayID
                let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                guard let scDisplay = content.displays.first(where: { display in
                    display.displayID == (screenNumber ?? 0)
                }) else {
                    let msg = "❌ Could not find matching SCDisplay for screen \(screen.frame)"
                    print(msg)
                    try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
                    semaphore.signal()
                    return
                }

                let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
                configuration.height = Int(screen.frame.height * screen.backingScaleFactor)

                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                capturedImage = NSImage(cgImage: image, size: screen.frame.size)

                let msg = "✅ ScreenCaptureKit: Captured (\(image.width)x\(image.height))"
                print(msg)
                try? msg.appendLine(to: "/tmp/iris_blink_debug.log")
            } catch {
                print("❌ ScreenCaptureKit error: \(error)")
                try? "❌ SCK error: \(error)".appendLine(to: "/tmp/iris_blink_debug.log")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return capturedImage
    }

    /// Legacy screen capture using CGWindowListCreateImage (macOS 13 and below)
    private func captureScreenLegacy(_ screen: NSScreen) -> NSImage? {
        // NSScreen.frame uses bottom-left origin (AppKit)
        // CGWindowListCreateImage expects top-left origin (CoreGraphics)
        // We need to convert the coordinate system

        let screenFrame = screen.frame

        // Find the maximum Y coordinate across all screens to determine the top of the coordinate space
        let maxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? screenFrame.maxY

        // Convert from AppKit (bottom-left origin) to CoreGraphics (top-left origin)
        // The top of the global coordinate space is at maxY
        // Formula: cgY = maxY - nsMaxY = maxY - (nsY + nsHeight)
        let cgRect = CGRect(
            x: screenFrame.origin.x,
            y: maxY - screenFrame.maxY,
            width: screenFrame.width,
            height: screenFrame.height
        )

        let msg1 = "📐 ScreenshotService: NSScreen frame (AppKit): \(screenFrame)"
        let msg2 = "📐 ScreenshotService: CGRect (CoreGraphics): \(cgRect)"
        let msg3 = "📐 ScreenshotService: Max Y across all screens: \(maxY)"
        print(msg1)
        print(msg2)
        print(msg3)
        try? msg1.appendLine(to: "/tmp/iris_blink_debug.log")
        try? msg2.appendLine(to: "/tmp/iris_blink_debug.log")
        try? msg3.appendLine(to: "/tmp/iris_blink_debug.log")

        // Capture everything on screen INCLUDING the overlay with highlights
        // This ensures the blue bounding box around focused elements is visible in the screenshot
        guard let fullImage = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            print("❌ ScreenshotService: Failed to capture screen")
            return nil
        }

        // CGWindowListCreateImage already captured the correct screen based on cgRect
        // Just wrap it in NSImage
        let image = NSImage(cgImage: fullImage, size: screenFrame.size)
        let msg4 = "✅ ScreenshotService: Screenshot (\(fullImage.width)x\(fullImage.height))"
        print(msg4)
        try? msg4.appendLine(to: "/tmp/iris_blink_debug.log")
        return image
    }

    /// Crops an image to specified bounds
    /// - Parameters:
    ///   - image: The CGImage to crop
    ///   - bounds: The bounds to crop to (in macOS coordinates - bottom-left origin)
    ///   - imageSize: The size of the original image
    /// - Returns: Cropped CGImage, or nil if crop fails
    public func cropImage(_ image: CGImage, to bounds: CGRect, imageSize: CGSize) -> CGImage? {
        print("🔍 ScreenshotService: Crop input - bounds=\(bounds), imageSize=\(imageSize)")

        // Convert from macOS coordinates (bottom-left origin) to CGImage coordinates (top-left origin)
        let flippedY = imageSize.height - bounds.origin.y - bounds.height

        let cropRect = CGRect(
            x: bounds.origin.x,
            y: flippedY,
            width: bounds.width,
            height: bounds.height
        )

        print("📐 ScreenshotService: Crop rect (before clamp): \(cropRect)")

        // Ensure crop rect is within image bounds
        let validRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))
        guard !validRect.isEmpty else {
            print("⚠️ ScreenshotService: Crop rect outside image bounds")
            return nil
        }

        print("✂️ ScreenshotService: Final crop rect: \(validRect)")
        let cropped = image.cropping(to: validRect)
        print("✅ ScreenshotService: Cropped to \(cropped?.width ?? 0)x\(cropped?.height ?? 0)")
        return cropped
    }

    /// Draws a bounding box on an image to highlight a focused region
    /// - Parameters:
    ///   - image: The NSImage to draw on
    ///   - bounds: The bounds of the region to highlight (in macOS coordinates - bottom-left origin)
    ///   - color: The color of the bounding box (default: system blue)
    ///   - lineWidth: The width of the bounding box border (default: 4)
    ///   - cornerRadius: The corner radius for rounded corners (default: 6)
    /// - Returns: New NSImage with bounding box drawn, or original image if drawing fails
    public func drawBoundingBox(on image: NSImage, bounds: CGRect, color: NSColor = .systemBlue, lineWidth: CGFloat = 4, cornerRadius: CGFloat = 6) -> NSImage {
        let imageSize = image.size

        // Create a new image to draw on
        let newImage = NSImage(size: imageSize)

        newImage.lockFocus()

        // Draw the original image first
        image.draw(at: .zero, from: NSRect(origin: .zero, size: imageSize), operation: .copy, fraction: 1.0)

        // Convert bounds from screen coordinates to image coordinates
        // macOS screen coordinates have origin at bottom-left, but NSImage drawing has origin at top-left
        let flippedY = imageSize.height - bounds.origin.y - bounds.height
        let drawRect = CGRect(
            x: bounds.origin.x,
            y: flippedY,
            width: bounds.width,
            height: bounds.height
        )

        // Create a bezier path with rounded corners
        let path = NSBezierPath(roundedRect: drawRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Set stroke properties for high visibility
        color.setStroke()
        path.lineWidth = lineWidth
        path.stroke()

        // Add a semi-transparent fill for even better visibility
        color.withAlphaComponent(0.1).setFill()
        path.fill()

        newImage.unlockFocus()

        print("✅ ScreenshotService: Drew bounding box at \(drawRect)")
        return newImage
    }

    /// Converts NSImage to JPEG base64 string
    /// - Parameters:
    ///   - image: The NSImage to convert
    ///   - compressionFactor: JPEG compression quality (0.0-1.0, default 0.8)
    /// - Returns: Base64 encoded JPEG string, or nil if conversion fails
    public func imageToBase64(_ image: NSImage, compressionFactor: CGFloat = 0.8) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor]) else {
            print("❌ ScreenshotService: Failed to convert image to JPEG")
            return nil
        }

        let base64 = jpegData.base64EncodedString()
        print("✅ ScreenshotService: Converted to base64 (\(jpegData.count) bytes)")
        return base64
    }
}
