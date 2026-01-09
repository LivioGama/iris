import SwiftUI
import AVFoundation
import Speech

@main
struct IRISApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("I.R.I.S", systemImage: "eye.circle.fill") {
            MenuBarView()
                .environmentObject(appDelegate.coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = IRISCoordinator()
    var overlayWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await requestAllPermissions()
            setupOverlayWindow()
            await coordinator.start()
            print("Auto-started tracking")
        }
    }
    
    private func setupOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false
        
        let hostingView = NSHostingView(rootView: OverlayView().environmentObject(coordinator))
        window.contentView = hostingView
        
        window.orderFrontRegardless()
        overlayWindow = window
        
        print("Overlay window created")
    }
    
    private func requestAllPermissions() async {
        let cameraGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
        print("Camera permission: \(cameraGranted)")
        
        let micGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        print("Microphone permission: \(micGranted)")
    }
}

struct ResolvedIntent: Identifiable {
    let id = UUID()
    let target: String
    let action: String
    let reasoning: String
    let confidence: Double
}
