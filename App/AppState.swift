import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isCapturing = false
    @Published var captureMode: CaptureMode = .area
    @Published var lastCapture: CaptureResult?
    @Published var showPreview = false
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var showOnboarding = false
    @Published var showSettings = false

    let settings = AppSettings.shared
    let permissions = PermissionService.shared
    let recentCaptures = RecentCapturesManager.shared

    private var overlayPanels: [NSPanel] = []
    private var toolbarPanel: NSPanel?
    private var previewPanel: NSPanel?
    private var toastPanel: NSPanel?

    private init() {}

    func startCapture(mode: CaptureMode? = nil) {
        permissions.checkPermissions()

        if !permissions.hasScreenRecordingPermission {
            permissions.openScreenRecordingSettings()
            return
        }

        isCapturing = true
        if let mode { captureMode = mode }

        switch captureMode {
        case .area:
            showAreaOverlay()
        case .window:
            showWindowOverlay()
        case .fullScreen:
            showFullScreenOverlay()
        }

        showToolbar()
    }

    func switchMode(_ mode: CaptureMode) {
        let previousMode = captureMode
        captureMode = mode

        if previousMode != mode {
            dismissOverlays()

            switch mode {
            case .area:
                showAreaOverlay()
            case .window:
                showWindowOverlay()
            case .fullScreen:
                showFullScreenOverlay()
            }
        }
    }

    func cancelCapture() {
        isCapturing = false
        dismissAllUI()
    }

    func completeCapture(image: NSImage) {
        isCapturing = false
        dismissAllUI()

        let copied = ClipboardService.shared.copyToClipboard(image)
        let savedURL = SaveService.shared.save(image, settings: settings)

        let result = CaptureResult(image: image, mode: captureMode, savedURL: savedURL)
        lastCapture = result
        recentCaptures.add(result)

        if settings.playCaptureSound {
            NSSound(named: "Tink")?.play()
        }

        if settings.showNotifications {
            let message: String
            if copied && savedURL != nil {
                message = "Saved and copied"
            } else if copied {
                message = "Copied to clipboard"
            } else {
                message = "Capture complete"
            }
            showToastNotification(message)
        }

        showPreviewThumbnail(result)
    }

    // MARK: - Area Overlay

    private func showAreaOverlay() {
        for screen in NSScreen.screens {
            let panel = OverlayPanel(screen: screen) { [weak self] rect, screen in
                self?.handleAreaSelection(rect: rect, screen: screen)
            } onCancel: { [weak self] in
                self?.cancelCapture()
            }
            panel.orderFrontRegardless()
            overlayPanels.append(panel)
        }
    }

    private func handleAreaSelection(rect: CGRect, screen: NSScreen) {
        dismissAllUI()

        let mainScreenHeight = NSScreen.screens[0].frame.height
        let captureRect = CGRect(
            x: rect.origin.x,
            y: mainScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            if let image = await CaptureService.shared.captureArea(rect: captureRect) {
                self?.completeCapture(image: image)
            }
        }
    }

    // MARK: - Window Overlay

    private func showWindowOverlay() {
        for screen in NSScreen.screens {
            let panel = WindowHighlightPanel(screen: screen) { [weak self] windowID in
                self?.handleWindowCapture(windowID: windowID)
            } onCancel: { [weak self] in
                self?.cancelCapture()
            }
            panel.orderFrontRegardless()
            overlayPanels.append(panel)
        }
    }

    private func handleWindowCapture(windowID: CGWindowID) {
        dismissAllUI()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            if let image = CaptureService.shared.captureWindow(windowID: windowID) {
                self?.completeCapture(image: image)
            }
        }
    }

    // MARK: - Full Screen Overlay

    private func showFullScreenOverlay() {
        for screen in NSScreen.screens {
            let panel = FullScreenHighlightPanel(screen: screen) { [weak self] targetScreen in
                self?.handleFullScreenCapture(screen: targetScreen)
            } onCancel: { [weak self] in
                self?.cancelCapture()
            }
            panel.orderFrontRegardless()
            overlayPanels.append(panel)
        }
    }

    private func handleFullScreenCapture(screen: NSScreen) {
        dismissAllUI()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            if let image = CaptureService.shared.captureFullScreen(screen: screen) {
                self?.completeCapture(image: image)
            }
        }
    }

    // MARK: - Toolbar

    private func showToolbar() {
        let toolbarView = CaptureToolbarView(appState: self)
        let hostingView = NSHostingView(rootView: toolbarView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 56)

        let screen = NSScreen.main ?? NSScreen.screens[0]
        // Position below the notch area (safe area inset ~38pt on notched Macs)
        let safeTop = screen.visibleFrame.maxY
        let panelFrame = NSRect(
            x: screen.frame.midX - 150,
            y: safeTop - 70,
            width: 300,
            height: 56
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar + 1
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentView = hostingView
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        toolbarPanel = panel
    }

    // MARK: - Preview Thumbnail

    private func showPreviewThumbnail(_ result: CaptureResult) {
        let previewView = PreviewThumbnailView(
            result: result,
            onSaveAs: { [weak self] in
                self?.dismissPreview()
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.png, .jpeg]
                panel.nameFieldStringValue = result.savedURL?.lastPathComponent ?? "SwiftSnap Screenshot.png"
                panel.canCreateDirectories = true
                if panel.runModal() == .OK, let url = panel.url {
                    if let tiffData = result.image.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData) {
                        let ext = url.pathExtension.lowercased()
                        let data: Data?
                        if ext == "jpg" || ext == "jpeg" {
                            data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                        } else {
                            data = bitmapRep.representation(using: .png, properties: [:])
                        }
                        try? data?.write(to: url, options: .atomic)
                    }
                }
            },
            onRename: { [weak self] in
                guard let savedURL = result.savedURL else { return }
                self?.dismissPreview()
                let panel = NSSavePanel()
                panel.directoryURL = savedURL.deletingLastPathComponent()
                panel.nameFieldStringValue = savedURL.lastPathComponent
                panel.allowedContentTypes = [.png, .jpeg]
                panel.canCreateDirectories = false
                if panel.runModal() == .OK, let newURL = panel.url {
                    try? FileManager.default.moveItem(at: savedURL, to: newURL)
                }
            },
            onDelete: { [weak self] in
                if let savedURL = result.savedURL {
                    try? FileManager.default.trashItem(at: savedURL, resultingItemURL: nil)
                }
                self?.dismissPreview()
            },
            onDismiss: { [weak self] in
                self?.dismissPreview()
            }
        )
        let hostingView = NSHostingView(rootView: previewView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 220, height: 220)

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let panelFrame = NSRect(
            x: screen.visibleFrame.maxX - 240,
            y: screen.visibleFrame.origin.y + 20,
            width: 220,
            height: 220
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        previewPanel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.dismissPreview()
        }
    }

    private func dismissPreview() {
        guard let panel = previewPanel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                panel.orderOut(nil)
                self?.previewPanel = nil
            }
        })
    }

    // MARK: - Toast

    private func showToastNotification(_ message: String) {
        toastMessage = message

        let toastView = NotificationToastView(message: message)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 44)

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let panelFrame = NSRect(
            x: screen.frame.midX - 100,
            y: screen.frame.origin.y + 60,
            width: 200,
            height: 44
        )

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        toastPanel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, let panel = self.toastPanel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor [weak self] in
                    panel.orderOut(nil)
                    self?.toastPanel = nil
                }
            })
        }
    }

    // MARK: - Dismiss

    private func dismissOverlays() {
        for panel in overlayPanels {
            panel.orderOut(nil)
        }
        overlayPanels.removeAll()
    }

    private func dismissAllUI() {
        dismissOverlays()

        if let toolbar = toolbarPanel {
            toolbar.orderOut(nil)
            toolbarPanel = nil
        }
    }
}
