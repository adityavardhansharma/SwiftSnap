import AppKit
import ScreenCaptureKit

final class PermissionService: ObservableObject {
    @Published var screenRecordingGranted = false
    @Published var accessibilityGranted = false

    func checkAllPermissions() {
        checkScreenRecording()
        checkAccessibility()
    }

    func checkScreenRecording() {
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func requestScreenRecording() {
        prepareForSystemPermissionPrompt()
        let granted = CGRequestScreenCaptureAccess()
        screenRecordingGranted = granted
        restoreAfterSystemPermissionPrompt()
    }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        prepareForSystemPermissionPrompt()
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibility()
            self?.restoreAfterSystemPermissionPrompt()
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func prepareForSystemPermissionPrompt() {
        DispatchQueue.main.async {
            for window in NSApp.windows where window.isVisible {
                window.level = .normal
                window.orderBack(nil)
            }
        }
    }

    private func restoreAfterSystemPermissionPrompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
