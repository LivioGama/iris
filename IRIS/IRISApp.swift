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
        requestPermissions()
    }
    
    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }
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
