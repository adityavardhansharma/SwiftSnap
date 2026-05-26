import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem
    private let captureService: CaptureService
    private let settingsStore: SettingsStore
    private let permissionService: PermissionService
    private let shortcutService: ShortcutService
    private let recentCapturesManager: RecentCapturesManager
    private var settingsWindow: NSWindow?

    init(
        captureService: CaptureService,
        settingsStore: SettingsStore,
        permissionService: PermissionService,
        shortcutService: ShortcutService,
        recentCapturesManager: RecentCapturesManager
    ) {
        self.captureService = captureService
        self.settingsStore = settingsStore
        self.permissionService = permissionService
        self.shortcutService = shortcutService
        self.recentCapturesManager = recentCapturesManager

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupMenuBarIcon()
        buildMenu()
    }

    private func setupMenuBarIcon() {
        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            icon?.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.imagePosition = .imageOnly
            button.toolTip = "SwiftSnap"

            if button.image == nil {
                button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SwiftSnap")
                button.image?.isTemplate = true
            }

            if button.image == nil {
                button.title = "SwiftSnap"
            }
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let captureItem = NSMenuItem(title: "Capture", action: #selector(handleCapture), keyEquivalent: "")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        captureItem.keyEquivalent = "s"
        captureItem.target = self
        captureItem.isEnabled = true
        menu.addItem(captureItem)

        menu.addItem(NSMenuItem.separator())

        // Capture modes
        for mode in CaptureMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(handleModeCapture(_:)), keyEquivalent: "")
            item.image = NSImage(systemSymbolName: mode.systemImage, accessibilityDescription: mode.rawValue)
            item.representedObject = mode
            item.target = self
            item.isEnabled = true
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Recent captures header
        let recentHeader = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
        recentHeader.isEnabled = false
        menu.addItem(recentHeader)

        // Recent captures submenu (will be populated dynamically)
        let recentSubmenu = NSMenu()
        let recentSubmenuItem = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
        recentSubmenuItem.submenu = recentSubmenu
        recentSubmenuItem.isEnabled = true
        menu.addItem(recentSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit SwiftSnap", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    @objc private func handleCapture() {
        captureService.startCapture()
    }

    @objc private func handleModeCapture(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? CaptureMode else { return }
        captureService.selectMode(mode)
    }

    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.title = "SwiftSnap Settings"
        window.center()

        let settingsView = SettingsView(settingsStore: settingsStore)
        window.contentView = NSHostingView(rootView: settingsView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func copyRecent(_ sender: NSMenuItem) {
        guard let capture = sender.representedObject as? CaptureResult else { return }
        let clipboard = ClipboardService()
        clipboard.copyToClipboard(capture.image)
    }

    @objc private func revealRecent(_ sender: NSMenuItem) {
        guard let capture = sender.representedObject as? CaptureResult else { return }
        recentCapturesManager.revealInFinder(capture)
    }

    @objc private func deleteRecent(_ sender: NSMenuItem) {
        guard let capture = sender.representedObject as? CaptureResult,
              let url = capture.savedURL else { return }
        try? FileManager.default.removeItem(at: url)
        recentCapturesManager.remove(id: capture.id)
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Update recent captures submenu
        guard let recentItem = menu.items.first(where: { $0.title == "Recent Captures" && $0.submenu != nil }),
              let submenu = recentItem.submenu else { return }

        submenu.removeAllItems()

        let captures = recentCapturesManager.recentCaptures

        if captures.isEmpty {
            let emptyItem = NSMenuItem(title: "No recent captures", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
            return
        }

        for capture in captures {
            let item = NSMenuItem(title: capture.displayName, action: nil, keyEquivalent: "")

            let captureSubmenu = NSMenu()

            let copyItem = NSMenuItem(title: "Copy Again", action: #selector(copyRecent(_:)), keyEquivalent: "")
            copyItem.target = self
            copyItem.representedObject = capture
            copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
            captureSubmenu.addItem(copyItem)

            if capture.savedURL != nil {
                let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(revealRecent(_:)), keyEquivalent: "")
                revealItem.target = self
                revealItem.representedObject = capture
                revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Reveal")
                captureSubmenu.addItem(revealItem)

                let deleteItem = NSMenuItem(title: "Delete File", action: #selector(deleteRecent(_:)), keyEquivalent: "")
                deleteItem.target = self
                deleteItem.representedObject = capture
                deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
                captureSubmenu.addItem(deleteItem)
            }

            item.submenu = captureSubmenu

            // Add small thumbnail
            let thumbnail = (capture.image.copy() as? NSImage) ?? capture.image
            thumbnail.size = NSSize(width: 32, height: 32 * (capture.image.size.height / capture.image.size.width))
            item.image = thumbnail

            submenu.addItem(item)
        }
    }
}
