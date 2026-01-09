import ScreenCaptureKit
import AppKit
import CoreGraphics

@MainActor
class ScreenCaptureService: ObservableObject {
    @Published var lastFullCapture: CGImage?
    @Published var lastCroppedCapture: CGImage?
    
    private var streamConfig: SCStreamConfiguration?
    private var filter: SCContentFilter?
    
    func captureFullScreen() async throws -> CGImage {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
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
    
    func captureCroppedRegion(around point: CGPoint, radius: CGFloat = 200) async throws -> CGImage {
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
    
    func imageToBase64(_ image: CGImage) -> String? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return data.base64EncodedString()
    }
}

enum ScreenCaptureError: Error {
    case noDisplay
    case croppingFailed
    case permissionDenied
}
