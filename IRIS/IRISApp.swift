import SwiftUI
import AVFoundation
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
    var mainDashboardWindow: NSWindow?
    var overlayWindows: [NSWindow] = []
    var demoControlWindow: NSWindow?
    var settingsWindow: NSWindow?
    var showcaseWindow: NSWindow?
    private var screenTimer: Timer?
    private var mouseMonitor: Any?
    private var currentMouseScreen: NSScreen?
    private let verboseLogsEnabled = ProcessInfo.processInfo.environment["IRIS_VERBOSE_LOGS"] == "1"

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

            setupMainDashboardWindow()
            setupOverlayWindows()
            setupDemoControlWindow()
            setupSettingsWindow()
            setupShowcaseWindow()
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

        // Fallback timer to update mouse screen periodically (events handle most updates).
        screenTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
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

            if verboseLogsEnabled {
                let screenName = newScreen == NSScreen.main ? "INTERNAL" : "EXTERNAL"
                let logMsg = "📍 Screen switched to: \(screenName) at \(newScreen.frame)"
                print(logMsg)
                try? logMsg.appendLine(to: "/tmp/iris_detection.log")
            }
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


    private func setupMainDashboardWindow() {
        mainDashboardWindow = nil
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

            window.level = .screenSaver  // Always on top, above all other windows (all screens)
            window.isOpaque = false
            window.backgroundColor = .clear
            // Mouse event handling is now managed by PassThroughWindow based on demo mode
            window.acceptsMouseMovedEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.hasShadow = false

            let hostingView = PassThroughHostingView(rootView: OverlayView(screen: screen).environmentObject(coordinator))
            window.contentView = hostingView

            // Ensure the window is ordered front but doesn't become key
            window.makeKeyAndOrderFront(nil)
            window.resignKey()

            overlayWindows.append(window)
        }

        print("Overlay windows created for \(overlayWindows.count) screen(s)")
    }

    private func setupDemoControlWindow() {
        // Only create if demo mode is enabled
        guard coordinator.geminiAssistant.demoAllTemplates else { return }

        guard let mainScreen = NSScreen.main else { return }

        let windowWidth: CGFloat = 280
        let windowHeight: CGFloat = 620
        let windowRect = NSRect(
            x: 20,
            y: mainScreen.frame.height - windowHeight - 80,
            width: windowWidth,
            height: windowHeight
        )

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let demoView = DemoControlPanelView()
            .environmentObject(coordinator)

        window.contentView = NSHostingView(rootView: demoView)
        window.makeKeyAndOrderFront(nil)

        demoControlWindow = window
        print("🎮 Demo control window created")

        // Auto-show first template if flag is enabled
        if coordinator.geminiAssistant.autoShowDemoOnLaunch {
            let demoSchemas = DynamicUIDemoGenerator.allDemoSchemas()
            if let firstSchema = demoSchemas.first {
                coordinator.geminiAssistant.dynamicUISchema = firstSchema
                coordinator.geminiAssistant.isOverlayVisible = true
                print("🎨 Auto-displaying first demo template: \(firstSchema.theme.title ?? "Unknown")")
            }
        }
    }

    private func setupSettingsWindow() {
        guard let mainScreen = NSScreen.main else { return }

        let windowWidth: CGFloat = 220
        let windowHeight: CGFloat = 110
        let windowRect = NSRect(
            x: mainScreen.frame.width - windowWidth - 40,
            y: mainScreen.frame.height - windowHeight - 40,
            width: windowWidth,
            height: windowHeight
        )

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let settingsView = IRISSettingsPanel()
            .environmentObject(coordinator)

        window.contentView = NSHostingView(rootView: settingsView)
        window.makeKeyAndOrderFront(nil)

        settingsWindow = window
        print("⚙️ Settings window created at top right")
    }

    private func setupShowcaseWindow() {
        // Only create if showcase mode is enabled
        guard coordinator.geminiAssistant.showAllTemplatesShowcase else { return }

        guard let mainScreen = NSScreen.main else { return }

        // Create a full-screen window to show all templates
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 10
        let windowRect = NSRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: mainScreen.frame.width - (horizontalPadding * 2),
            height: mainScreen.frame.height - (verticalPadding * 2)
        )

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let showcaseView = AllTemplatesShowcaseView(onClose: { [weak self] in
            self?.showcaseWindow?.orderOut(nil)
            self?.showcaseWindow = nil
        })

        let hostingView = NSHostingView(rootView: showcaseView)
        hostingView.frame = window.contentView?.bounds ?? windowRect
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        showcaseWindow = window
        print("🎨 Showcase window created - size: \(windowRect.width)x\(windowRect.height)")
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

/// Custom window that always passes through mouse events - overlay is purely visual
class PassThroughWindow: NSWindow {
    weak var coordinator: IRISCoordinator?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool, coordinator: IRISCoordinator) {
        self.coordinator = coordinator
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        // Always pass through - overlay is purely visual
        self.ignoresMouseEvents = true
    }
}

/// Custom hosting view that always passes through clicks
class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
