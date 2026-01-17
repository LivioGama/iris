import Foundation
import Vision
import ScreenCaptureKit
import AppKit

func testVisionDetection() async {
    print("Testing Vision text detection...")

    // Check permissions
    print("Checking permissions...")
    print("Screen recording available: \(CGPreflightScreenCaptureAccess())")
    print("Screen recording granted: \(CGRequestScreenCaptureAccess())")

    do {
        print("Getting shareable content...")
        // Capture screen
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            print("❌ No display found")
            return
        }

        print("✅ Found display: \(display.width)x\(display.height)")

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        print("Capturing screenshot...")
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        print("✅ Screen captured: \(image.width)x\(image.height)")

        // Try text detection
        print("Running text recognition...")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        if let results = request.results {
            print("✅ Found \(results.count) text observations")
            for (i, observation) in results.prefix(5).enumerated() {
                if let text = observation.topCandidates(1).first?.string {
                    print("  \(i+1): \"\(text)\" at (\(Int(observation.boundingBox.midX * CGFloat(image.width))), \(Int(observation.boundingBox.midY * CGFloat(image.height))))")
                }
            }
        } else {
            print("❌ No text observations found")
        }

    } catch let error as SCStreamError {
        print("❌ Screen capture error: \(error)")
    } catch {
        print("❌ Error: \(error)")
    }
}

Task {
    await testVisionDetection()
}