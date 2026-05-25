import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    private let appState = AppState.shared
    private let shortcutService = ShortcutService.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupShortcut()
        setupObservers()

        if !appState.settings.hasCompletedOnboarding {
            showOnboarding()
        }

        appState.permissions.checkPermissions()
    }

    private func setupObservers() {
        appState.$showSettings
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.showSettings()
                    self.appState.showSettings = false
                }
            }
            .store(in: &cancellables)

        appState.$showOnboarding
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.showOnboarding()
                    self.appState.showOnboarding = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let iconImage = NSImage(named: "MenuBarIcon") {
                iconImage.size = NSSize(width: 18, height: 18)
                iconImage.isTemplate = true
                button.image = iconImage
            } else {
                button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SwiftSnap")
                button.image?.size = NSSize(width: 18, height: 18)
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 340)
        popover.behavior = .transient
        popover.animates = true
        popover.setValue(true, forKeyPath: "shouldHideAnchor")
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                appState: appState,
                recentCaptures: appState.recentCaptures,
                settings: appState.settings
            )
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Shortcut

    private func setupShortcut() {
        shortcutService.onTrigger = { [weak self] in
            DispatchQueue.main.async {
                self?.popover?.performClose(nil)
                self?.appState.startCapture(mode: .area)
            }
        }
        shortcutService.register()
    }

    // MARK: - Settings

    func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settings: appState.settings)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SwiftSnap Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 500, height: 400))

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.midY - windowSize.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - Onboarding

    func showOnboarding() {
        let onboardingView = OnboardingView(
            settings: appState.settings,
            permissions: appState.permissions
        )
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.center()
        window.isReleasedWhenClosed = false
        window.hasShadow = true
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutService.unregister()
    }
}
