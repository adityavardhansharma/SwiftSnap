import AppKit
import ScreenCaptureKit

final class PermissionService: ObservableObject {
    @Published var screenRecordingGranted = false
    @Published var accessibilityGranted = false

    /// Saved window levels so we can restore them after a permission flow.
    private var savedLevels: [(window: NSWindow, level: NSWindow.Level)] = []
    private var isWaitingForPermission = false
    private var didBecomeActiveObserver: NSObjectProtocol?

    init() {
        // When the user returns to our app on their own (e.g. after granting
        // permission and clicking back), bring our windows back to the front.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }
    }

    deinit {
        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func checkAllPermissions() {
        checkScreenRecording()
        checkAccessibility()
    }

    func checkScreenRecording() {
        let granted = CGPreflightScreenCaptureAccess()
        screenRecordingGranted = granted
        if granted && isWaitingForPermission {
            restoreWindowLevels()
        }
    }

    func requestScreenRecording() {
        prepareForSystemPermissionPrompt()
        let granted = CGRequestScreenCaptureAccess()
        screenRecordingGranted = granted
        if granted {
            restoreWindowLevels()
        }
        // If not granted, leave windows lowered so the user can interact
        // with System Settings unimpeded. They'll be restored when the user
        // returns to our app (didBecomeActive) or permission is granted.
    }

    func checkAccessibility() {
        let granted = AXIsProcessTrusted()
        accessibilityGranted = granted
        if granted && isWaitingForPermission {
            restoreWindowLevels()
        }
    }

    func requestAccessibility() {
        prepareForSystemPermissionPrompt()
        // Trigger TCC registration so SwiftSnap appears in
        // System Settings → Privacy & Security → Accessibility,
        // and show the system "open Settings" prompt the first time.
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // Belt-and-suspenders: also open the Accessibility settings pane
        // directly. The system prompt only fires once, but the user may
        // need to re-open Settings on subsequent attempts.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, !self.accessibilityGranted else { return }
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func openScreenRecordingSettings() {
        prepareForSystemPermissionPrompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        prepareForSystemPermissionPrompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Drop all visible windows to .normal level and push them behind, so
    /// System Settings (and the system permission dialog) can render on top.
    private func prepareForSystemPermissionPrompt() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.isWaitingForPermission {
                self.savedLevels = NSApp.windows
                    .filter { $0.isVisible }
                    .map { ($0, $0.level) }
            }
            self.isWaitingForPermission = true
            for entry in self.savedLevels {
                entry.window.level = .normal
                entry.window.orderBack(nil)
            }
        }
    }

    /// Put our windows back to whatever level they had before the permission
    /// flow started. Called when permission is granted, or when the user
    /// manually switches back to our app.
    private func restoreWindowLevels() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.isWaitingForPermission else { return }
            for entry in self.savedLevels {
                entry.window.level = entry.level
            }
            self.savedLevels.removeAll()
            self.isWaitingForPermission = false
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func handleAppDidBecomeActive() {
        guard isWaitingForPermission else { return }
        // The "open System Settings" link in the system permission popup
        // briefly makes our app active before Settings takes focus. Wait
        // half a second and only restore if we're still really the front
        // app — otherwise the user is genuinely interacting with Settings.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            guard self.isWaitingForPermission else { return }
            guard NSApp.isActive else { return }
            self.checkScreenRecording()
            self.checkAccessibility()
            self.restoreWindowLevels()
        }
    }
}
