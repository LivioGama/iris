import SwiftUI
import AVFoundation
import Speech
import Combine
import IRISGaze
import IRISCore

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
    // Using dependency injection via container
    let coordinator = DependencyContainer.shared.makeCoordinator()
    var overlayWindows: [NSWindow] = []
    private var screenTimer: Timer?
    private var mouseMonitor: Any?
    private var currentMouseScreen: NSScreen?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startAppServices()
    }

    private func startAppServices() {
        // Cleanup any orphaned processes from previous crashes
        cleanupOrphanedProcesses()

        // Setup signal handlers to cleanup Python processes on crash
        setupSignalHandlers()

        // Register atexit handler as last resort
        atexit {
            AppDelegate.emergencyCleanup()
        }

        Task {
            await requestAllPermissions()

            // Check for API key and show input if missing
            checkAndRequestAPIKey()

            setupOverlayWindows()
            setupMouseTracking()
            await coordinator.start()
            print("Auto-started tracking")
        }
    }



    func applicationWillTerminate(_ notification: Notification) {
        // Ensure Python processes are stopped
        print("🛑 App terminating, cleaning up...")
        coordinator.stop()
        cleanupOrphanedProcesses()
    }

    private func setupSignalHandlers() {
        // Handle crashes and forced terminations
        signal(SIGTERM) { _ in
            print("🛑 SIGTERM received, cleaning up...")
            AppDelegate.emergencyCleanup()
            exit(0)
        }

        signal(SIGINT) { _ in
            print("🛑 SIGINT received, cleaning up...")
            AppDelegate.emergencyCleanup()
            exit(0)
        }

        signal(SIGABRT) { _ in
            print("🛑 SIGABRT received, cleaning up...")
            AppDelegate.emergencyCleanup()
            exit(134)
        }

        signal(SIGSEGV) { _ in
            print("🛑 SIGSEGV received, cleaning up...")
            AppDelegate.emergencyCleanup()
            exit(139)
        }
    }

    static func emergencyCleanup() {
        // This is called from signal handlers and atexit
        // Must be async-signal-safe operations only

        // Use only async-signal-safe system calls
        // Call pkill directly using posix_spawn (signal-safe)
        var pid: pid_t = 0
        var argv: [UnsafeMutablePointer<CChar>?] = [
            strdup("/usr/bin/pkill"),
            strdup("-9"),
            strdup("-f"),
            strdup("eye_tracker.py"),
            nil
        ]

        defer {
            // Clean up allocated strings
            for i in 0..<argv.count - 1 {
                free(argv[i])
            }
        }

        // Use posix_spawn which is async-signal-safe
        posix_spawn(&pid, "/usr/bin/pkill", nil, nil, &argv, nil)
    }

    private func checkAndRequestAPIKey() {
        if !DependencyContainer.shared.hasAPIKey() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let apiKeyWindow = APIKeyInputWindow(
                    onSave: { apiKey in
                        if apiKey.isEmpty {
                            return false
                        }
                        DependencyContainer.shared.saveAPIKey(apiKey)
                        return true
                    },
                    onCancel: {
                        print("⚠️ API Key setup cancelled - Gemini features will not work")
                    }
                )
                apiKeyWindow.showWindow()
            }
        }
    }

    private func cleanupOrphanedProcesses() {
        // Import the cleanup function
        IRISGaze.PythonProcessManager.cleanupOrphanedProcesses()

        // Additional fallback cleanup
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-9", "-f", "eye_tracker.py"]
        try? task.run()
        task.waitUntilExit()
    }

    private func setupMouseTracking() {
        // Track mouse movements globally
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            Task { @MainActor in
                self?.updateMouseScreen()
            }
        }

        // Initial update
        updateMouseScreen()

        // Fallback timer to update mouse screen periodically
        screenTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMouseScreen()
            }
        }
    }

    private func updateMouseScreen() {
        let mouseLocation = NSEvent.mouseLocation

        // Find which screen contains the mouse
        let screenWithMouse = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }

        // Only update if screen changed
        if let newScreen = screenWithMouse, newScreen !== currentMouseScreen {
            currentMouseScreen = newScreen
            updateActiveScreen(for: newScreen)

            // Update coordinator with current screen for screen capture
            coordinator.currentScreen = newScreen

            let screenName = newScreen == NSScreen.main ? "INTERNAL" : "EXTERNAL"
            let logMsg = "📍 Screen switched to: \(screenName) at \(newScreen.frame)"
            print(logMsg)
            try? logMsg.appendLine(to: "/tmp/iris_detection.log")
        }
    }

    private func updateActiveScreen(for screen: NSScreen) {
        // Show only the window for the screen with the mouse
        for (index, window) in overlayWindows.enumerated() {
            if index < NSScreen.screens.count {
                let windowScreen = NSScreen.screens[index]
                if windowScreen === screen {
                    window.orderFrontRegardless()
                } else {
                    window.orderOut(nil)
                }
            }
        }
    }


    private func setupOverlayWindows() {
        for screen in NSScreen.screens {
            let window = PassThroughWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                coordinator: coordinator
            )

            window.level = .statusBar  // Always on top, above all other windows
            window.isOpaque = false
            window.backgroundColor = .clear
            // Don't use ignoresMouseEvents - let SwiftUI views control hit testing
            // window.ignoresMouseEvents = true
            window.acceptsMouseMovedEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.hasShadow = false

            let hostingView = NSHostingView(rootView: OverlayView(screen: screen).environmentObject(coordinator))
            window.contentView = hostingView

            // Ensure the window is ordered front but doesn't become key
            window.makeKeyAndOrderFront(nil)
            window.resignKey()

            overlayWindows.append(window)
        }

        print("Overlay windows created for \(overlayWindows.count) screen(s)")
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

/// Custom window that passes through mouse events when Gemini overlay is inactive
class PassThroughWindow: NSWindow {
    weak var coordinator: IRISCoordinator?
    private var updateTimer: Timer?

    // CRITICAL: Override to prevent focus stealing
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool, coordinator: IRISCoordinator) {
        self.coordinator = coordinator
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        // Start timer to update ignoresMouseEvents based on Gemini state
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMouseEventHandling()
        }
    }

    private func updateMouseEventHandling() {
        guard let coordinator = coordinator else { return }

        // Only allow clicks when overlay is active (has screenshot or chat messages)
        let overlayIsActive = coordinator.geminiAssistant.capturedScreenshot != nil ||
                             !coordinator.geminiAssistant.chatMessages.isEmpty

        // When overlay is active, allow clicks on the overlay content
        // When overlay is inactive (just gaze indicator), pass through all clicks
        self.ignoresMouseEvents = !overlayIsActive
    }

    deinit {
        updateTimer?.invalidate()
    }
}
