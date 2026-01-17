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
    private var mouseEventObserver: AnyCancellable?
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
            setupMouseEventObserver()
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

    private func setupMouseEventObserver() {
        // When ONLY gaze indicator is showing: ignore mouse events (click-through)
        // When Gemini overlay is active: accept mouse events for interactive UI
        mouseEventObserver = coordinator.$shouldAcceptMouseEvents
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldAccept in
                self?.overlayWindows.forEach { window in
                    // shouldAccept = true when Gemini overlay is active (needs clicks)
                    // shouldAccept = false when only gaze indicator is showing (click-through)
                    window.ignoresMouseEvents = !shouldAccept
                }
            }
    }

    private func setupOverlayWindows() {
        for screen in NSScreen.screens {
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
