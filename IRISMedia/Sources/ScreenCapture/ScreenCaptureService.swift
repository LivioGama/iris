import ScreenCaptureKit
import AppKit
import CoreGraphics

@MainActor
public class ScreenCaptureService: ObservableObject {
    public init() {}

    @Published public var lastFullCapture: CGImage?
    @Published public var lastCroppedCapture: CGImage?

    private var streamConfig: SCStreamConfiguration?
    private var filter: SCContentFilter?

    public var preferredScreen: NSScreen?

    public func captureFullScreen() async throws -> CGImage {
        let content = try await SCShareableContent.current

        // Use preferred screen if available, otherwise fall back to first display
        var targetDisplay: SCDisplay?

        if let preferredScreen = preferredScreen {
            // Find the display that matches the preferred screen
            let nsScreens = NSScreen.screens
            for (index, display) in content.displays.enumerated() {
                if index < nsScreens.count && nsScreens[index] === preferredScreen {
                    targetDisplay = display
                    break
                }
            }
        }

        // Fallback to first display if no match
        let display = targetDisplay ?? content.displays.first

        guard let display = display else {
            throw ScreenCaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        lastFullCapture = image
        return image
    }

    public func captureScreen(at point: CGPoint) async throws -> CGImage {
        let content = try await SCShareableContent.current

        // Prefer the preferred screen if set, otherwise find by point
        let nsScreens = NSScreen.screens
        var targetDisplay: SCDisplay?

        if let preferredScreen = preferredScreen {
            // Find the display that matches the preferred screen
            for (index, display) in content.displays.enumerated() {
                if index < nsScreens.count && nsScreens[index] === preferredScreen {
                    targetDisplay = display
                    break
                }
            }
        } else {
            // Find the display that contains the gaze point using NSScreen coordinates
            for (index, display) in content.displays.enumerated() {
                if index < nsScreens.count {
                    let nsScreen = nsScreens[index]
                    let screenFrame = nsScreen.frame
                    if screenFrame.contains(point) {
                        targetDisplay = display
                        break
                    }
                }
            }
        }

        // Fallback to first display if no match found
        let display = targetDisplay ?? content.displays.first

        guard let targetDisplay = display else {
            throw ScreenCaptureError.noDisplay
        }

        let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(targetDisplay.width)
        config.height = Int(targetDisplay.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        lastFullCapture = image
        return image
    }

    public func captureCroppedRegion(around point: CGPoint, radius: CGFloat = 200) async throws -> CGImage {
        let fullImage = try await captureFullScreen()

        let rect = CGRect(
            x: max(0, point.x - radius),
            y: max(0, point.y - radius),
            width: radius * 2,
            height: radius * 2
        )

        guard let croppedImage = fullImage.cropping(to: rect) else {
            throw ScreenCaptureError.croppingFailed
        }

        lastCroppedCapture = croppedImage
        return croppedImage
    }

    public func imageToBase64(_ image: CGImage) -> String? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return data.base64EncodedString()
    }
}

public enum ScreenCaptureError: Error {
    case noDisplay
    case croppingFailed
    case permissionDenied
}
