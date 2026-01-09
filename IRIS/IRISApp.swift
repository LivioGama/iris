import SwiftUI

@main
struct IRISApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        
        MenuBarExtra("I.R.I.S", systemImage: "eye.circle.fill") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await requestAllPermissions()
        }
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
        
        print("Skipping speech recognition authorization (requires app bundle)")
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isTracking = false
    @Published var gazePoint: CGPoint = .zero
    @Published var lastTranscript = ""
    @Published var lastIntent: ResolvedIntent?
    @Published var isProcessing = false
}

struct ResolvedIntent: Identifiable {
    let id = UUID()
    let target: String
    let action: String
    let reasoning: String
    let confidence: Double
}

import AVFoundation
import Speech
