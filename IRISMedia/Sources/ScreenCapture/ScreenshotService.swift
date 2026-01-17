import Foundation
import AppKit

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
        let rect = screen.frame

        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            print("❌ ScreenshotService: Failed to capture screen")
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        print("📸 ScreenshotService: Captured screenshot (\(cgImage.width)x\(cgImage.height))")
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
