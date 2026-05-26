import AppKit
import SwiftUI
import ScreenCaptureKit
import Combine

enum CaptureState {
    case idle
    case toolbar
    case capturing(CaptureMode)
    case preview(CaptureResult)
}

final class CaptureService: ObservableObject {
    @Published var state: CaptureState = .idle
    @Published var selectedMode: CaptureMode = .area
    @Published var currentResult: CaptureResult?

    private let clipboardService: ClipboardService
    private let saveService: SaveService
    private let settingsStore: SettingsStore
    private let recentCapturesManager: RecentCapturesManager

    private var toolbarWindow: NSWindow?
    private var previewWindow: NSWindow?
    private var overlayWindows: [NSWindow] = []
    private var escapeMonitorLocal: Any?
    private var escapeMonitorGlobal: Any?
    private var didPushCrosshairCursor = false

    init(
        clipboardService: ClipboardService,
        saveService: SaveService,
        settingsStore: SettingsStore,
        recentCapturesManager: RecentCapturesManager
    ) {
        self.clipboardService = clipboardService
        self.saveService = saveService
        self.settingsStore = settingsStore
        self.recentCapturesManager = recentCapturesManager
    }

    func startCapture() {
        dismissTransientCaptureUI()
        selectedMode = .area
        state = .toolbar
        if !ProcessInfo.processInfo.isRunningTests {
            showToolbar()
        }
    }

    func selectMode(_ mode: CaptureMode) {
        selectedMode = mode
        hideToolbarImmediately()
        dismissOverlays()

        switch mode {
        case .area:
            beginSystemCapture(arguments: ["-i", "-s", "-x"], mode: .area)
        case .window:
            beginSystemCapture(arguments: ["-i", "-w", "-x"], mode: .window)
        case .fullScreen:
            beginSystemCapture(arguments: ["-x"], mode: .fullScreen)
        }
    }

    func startQuickCapture() {
        dismissTransientCaptureUI()
        selectMode(selectedMode)
    }

    func cancelCapture() {
        dismissTransientCaptureUI()
        state = .idle
    }

    func handleCapturedImage(_ image: NSImage) {
        clipboardService.copyToClipboard(image)

        var savedURL: URL?

        if !settingsStore.clipboardOnly {
            let folder = settingsStore.saveFolderURL
            let accessed = folder?.startAccessingSecurityScopedResource() ?? false
            savedURL = saveService.save(image: image)
            if accessed {
                folder?.stopAccessingSecurityScopedResource()
            }
        }

        let displayName = savedURL?.deletingPathExtension().lastPathComponent
        let result = CaptureResult(image: image, savedURL: savedURL, displayName: displayName)

        currentResult = result
        recentCapturesManager.add(result)
        state = .idle
        if !ProcessInfo.processInfo.isRunningTests {
            showThumbnailPreview(result)
        }

        if settingsStore.captureSound {
            NSSound(named: "Tink")?.play()
        }
    }

    func saveAs() {
        guard let result = currentResult else { return }
        if let url = saveService.saveAs(image: result.image, suggestedName: result.displayName) {
            currentResult?.savedURL = url
            let displayName = url.deletingPathExtension().lastPathComponent
            currentResult?.displayName = displayName
            recentCapturesManager.updateMetadata(id: result.id, savedURL: url, displayName: displayName)
        }
    }

    func rename(newName: String) {
        guard let result = currentResult, let url = result.savedURL else { return }
        if let newURL = saveService.rename(at: url, to: newName) {
            currentResult?.savedURL = newURL
            let displayName = newURL.deletingPathExtension().lastPathComponent
            currentResult?.displayName = displayName
            recentCapturesManager.updateMetadata(id: result.id, savedURL: newURL, displayName: displayName)
        }
    }

    func deleteFile() {
        guard let result = currentResult, let url = result.savedURL else { return }
        if saveService.delete(at: url) {
            currentResult?.savedURL = nil
            recentCapturesManager.updateSavedURL(id: result.id, url: nil)
        }
    }

    // MARK: - Escape Monitors

    private func installEscapeMonitors() {
        removeEscapeMonitors()

        escapeMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancelCapture()
                return nil
            }
            return event
        }

        escapeMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancelCapture()
            }
        }
    }

    private func removeEscapeMonitors() {
        if let monitor = escapeMonitorLocal {
            NSEvent.removeMonitor(monitor)
            escapeMonitorLocal = nil
        }
        if let monitor = escapeMonitorGlobal {
            NSEvent.removeMonitor(monitor)
            escapeMonitorGlobal = nil
        }
    }

    // MARK: - Toolbar

    private func showToolbar() {
        guard let screen = NSScreen.main else { return }
        hideToolbarImmediately()
        let toolbarWidth: CGFloat = 440
        let toolbarHeight: CGFloat = 70
        let toolbarX = screen.frame.midX - toolbarWidth / 2
        let toolbarY = screen.visibleFrame.maxY - toolbarHeight - 18

        let panel = FloatingPanel(
            contentRect: NSRect(x: toolbarX, y: toolbarY, width: toolbarWidth, height: toolbarHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true

        panel.contentView = NSHostingView(rootView: OfficialCaptureToolbarView(captureService: self))
        panel.makeKeyAndOrderFront(nil)

        toolbarWindow = panel
        installEscapeMonitors()
    }

    private func hideToolbarImmediately() {
        toolbarWindow?.orderOut(nil)
        toolbarWindow?.contentView = nil
        toolbarWindow = nil
    }

    // MARK: - Thumbnail Preview

    private func showThumbnailPreview(_ result: CaptureResult) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        previewWindow?.orderOut(nil)
        previewWindow?.contentView = nil

        let previewSize = NSSize(width: 320, height: 280)
        let frame = clampedPreviewFrame(size: previewSize, on: screen)

        let panel = FloatingPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isFloatingPanel = true

        panel.contentView = NSHostingView(rootView: CapturePreviewGlassView(captureService: self, result: result) { [weak self] in
            self?.previewWindow?.orderOut(nil)
            self?.previewWindow?.contentView = nil
            self?.previewWindow = nil
        })
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        previewWindow = panel
    }

    private func clampedPreviewFrame(size: NSSize, on screen: NSScreen) -> NSRect {
        let margin: CGFloat = 24
        let visibleFrame = screen.visibleFrame.insetBy(dx: margin, dy: margin)
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)

        let preferredX = visibleFrame.maxX - width
        let preferredY = visibleFrame.minY
        let x = min(max(preferredX, visibleFrame.minX), visibleFrame.maxX - width)
        let y = min(max(preferredY, visibleFrame.minY), visibleFrame.maxY - height)

        return NSRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Native macOS Capture

    private func beginSystemCapture(arguments: [String], mode: CaptureMode) {
        state = .capturing(mode)
        removeEscapeMonitors()

        guard ensureScreenCapturePermission() else {
            state = .idle
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftSnap-\(UUID().uuidString)")
            .appendingPathExtension("png")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments + [tempURL.path]

            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    guard let self else { return }
                    defer {
                        try? FileManager.default.removeItem(at: tempURL)
                    }

                    guard process.terminationStatus == 0,
                          FileManager.default.fileExists(atPath: tempURL.path),
                          let image = NSImage(contentsOf: tempURL) else {
                        self.state = .idle
                        return
                    }

                    self.handleCapturedImage(image)
                }
            }

            do {
                try process.run()
            } catch {
                self.state = .idle
            }
        }
    }

    private func ensureScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        return CGRequestScreenCaptureAccess()
    }

    func dismissOverlays() {
        if didPushCrosshairCursor {
            NSCursor.pop()
            didPushCrosshairCursor = false
        }
        removeEscapeMonitors()
        for window in overlayWindows {
            window.orderOut(nil)
            window.contentView = nil
        }
        overlayWindows.removeAll()
    }

    private func dismissTransientCaptureUI() {
        removeEscapeMonitors()
        hideToolbarImmediately()
        dismissOverlays()
    }

}

extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}

// MARK: - Capture Toolbar (Liquid Glass)

private struct OfficialCaptureToolbarView: View {
    @ObservedObject var captureService: CaptureService

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 4) {
                toolbarModeButton(
                    title: "Area",
                    systemImage: "selection.pin.in.out",
                    isSelected: captureService.selectedMode == .area
                ) {
                    captureService.selectMode(.area)
                }

                toolbarModeButton(
                    title: "Window",
                    systemImage: "macwindow",
                    isSelected: captureService.selectedMode == .window
                ) {
                    captureService.selectMode(.window)
                }

                toolbarModeButton(
                    title: "Screen",
                    systemImage: "display",
                    isSelected: captureService.selectedMode == .fullScreen
                ) {
                    captureService.selectMode(.fullScreen)
                }
            }
            .padding(6)
            .glassEffect(.regular, in: .capsule)
            .shadow(color: .black.opacity(0.32), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.14), radius: 3, x: 0, y: 1)
        }
    }

    private func toolbarModeButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.primary)
                .frame(width: 118, height: 40)
                .contentShape(Capsule())
                .overlay {
                    if isSelected {
                        Capsule()
                            .strokeBorder(.white.opacity(0.65), lineWidth: 1.2)
                            .blendMode(.plusLighter)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thumbnail Preview (Liquid Glass)

private struct CapturePreviewGlassView: View {
    let captureService: CaptureService
    let result: CaptureResult
    let onDismiss: () -> Void
    @State private var temporaryPreviewURL: URL?
    @State private var autoDismissTask: Task<Void, Never>?
    @State private var isHovered = false

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    actionButton(icon: "eye", tip: "Open in Preview") {
                        cancelAutoDismiss(); openInPreview()
                    }
                    actionButton(icon: "square.and.arrow.down", tip: "Save As") {
                        cancelAutoDismiss(); captureService.saveAs()
                    }
                    actionButton(icon: "pencil", tip: "Rename") {
                        cancelAutoDismiss(); rename()
                    }
                    actionButton(icon: "trash", tip: "Delete") {
                        captureService.deleteFile(); onDismiss()
                    }
                    actionButton(icon: "xmark", tip: "Close", action: onDismiss)
                }
                .padding(6)
                .glassEffect(.regular, in: .capsule)
                .shadow(color: .black.opacity(0.32), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.14), radius: 3, x: 0, y: 1)

                Button {
                    cancelAutoDismiss(); openInPreview()
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        Image(nsImage: result.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 290, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                        Text(result.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(maxWidth: 200, alignment: .leading)
                            .glassEffect(.regular, in: .capsule)
                            .padding(10)
                    }
                }
                .buttonStyle(.plain)
                .help("Open in Preview")
            }
        }
        .frame(width: 316, height: 270)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                cancelAutoDismiss()
            } else {
                scheduleAutoDismiss()
            }
        }
        .onAppear {
            scheduleAutoDismiss()
        }
        .onDisappear {
            cancelAutoDismiss()
        }
    }

    private func actionButton(icon: String, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    private func scheduleAutoDismiss() {
        cancelAutoDismiss()
        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, !isHovered else { return }
            onDismiss()
        }
    }

    private func cancelAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
    }

    private func openInPreview() {
        guard let url = result.savedURL ?? writeTemporaryPreviewImage() else { return }
        let previewURL = URL(fileURLWithPath: "/System/Applications/Preview.app")
        NSWorkspace.shared.open([url], withApplicationAt: previewURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func rename() {
        let alert = NSAlert()
        alert.messageText = "Rename Screenshot"
        alert.informativeText = "Enter a new filename."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = result.displayName
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        captureService.rename(newName: field.stringValue)
    }

    private func writeTemporaryPreviewImage() -> URL? {
        if let temporaryPreviewURL {
            return temporaryPreviewURL
        }
        guard let tiffData = result.image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(result.displayName)
            .appendingPathExtension("png")

        do {
            try pngData.write(to: url, options: .atomic)
            temporaryPreviewURL = url
            return url
        } catch {
            return nil
        }
    }
}

