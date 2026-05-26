import SwiftUI

@main
struct SwiftSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class FloatingPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var onboardingWindow: NSWindow?
    private var settingsStore: SettingsStore?
    private var permissionService: PermissionService?
    private var clipboardService: ClipboardService?
    private var saveService: SaveService?
    private var recentCapturesManager: RecentCapturesManager?
    private var captureService: CaptureService?
    private var shortcutService: ShortcutService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settingsStore = SettingsStore()
        let permissionService = PermissionService()
        let clipboardService = ClipboardService()
        let saveService = SaveService(settingsStore: settingsStore)
        let recentCapturesManager = RecentCapturesManager()
        let captureService = CaptureService(
            clipboardService: clipboardService,
            saveService: saveService,
            settingsStore: settingsStore,
            recentCapturesManager: recentCapturesManager
        )
        let shortcutService = ShortcutService(captureService: captureService)

        self.settingsStore = settingsStore
        self.permissionService = permissionService
        self.clipboardService = clipboardService
        self.saveService = saveService
        self.recentCapturesManager = recentCapturesManager
        self.captureService = captureService
        self.shortcutService = shortcutService

        menuBarController = MenuBarController(
            captureService: captureService,
            settingsStore: settingsStore,
            permissionService: permissionService,
            shortcutService: shortcutService,
            recentCapturesManager: recentCapturesManager
        )

        _ = shortcutService.register()

        if !ProcessInfo.processInfo.isRunningTests && !settingsStore.hasCompletedOnboarding {
            showOnboarding(settingsStore: settingsStore, permissionService: permissionService)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showOnboarding(settingsStore: SettingsStore, permissionService: PermissionService) {
        let window = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false

        let onboardingView = OnboardingView(
            settingsStore: settingsStore,
            permissionService: permissionService
        ) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.close()
                self.onboardingWindow = nil
            })
        }

        window.contentView = NSHostingView(rootView: onboardingView)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }
}
