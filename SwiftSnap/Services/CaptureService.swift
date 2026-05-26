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
        let toolbarWidth: CGFloat = 430
        let toolbarHeight: CGFloat = 56
        let toolbarX = screen.frame.midX - toolbarWidth / 2
        let toolbarY = screen.visibleFrame.maxY - toolbarHeight - 18

        let window = FloatingPanel(
            contentRect: NSRect(x: toolbarX, y: toolbarY, width: toolbarWidth, height: toolbarHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false

        window.contentView = NSHostingView(rootView: OfficialCaptureToolbarView(captureService: self))
        window.makeKeyAndOrderFront(nil)

        toolbarWindow = window
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

        let previewSize = NSSize(width: 316, height: 226)
        let frame = clampedPreviewFrame(size: previewSize, on: screen)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isMovable = false
        window.contentMinSize = previewSize
        window.contentMaxSize = previewSize
        window.contentView = NSHostingView(rootView: CapturePreviewGlassView(captureService: self, result: result) { [weak self] in
            self?.previewWindow?.orderOut(nil)
            self?.previewWindow?.contentView = nil
            self?.previewWindow = nil
        })
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        previewWindow = window
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

    // MARK: - Area Capture

    private func beginAreaCapture() {
        state = .capturing(.area)
        installEscapeMonitors()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.001)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = false
            window.hasShadow = false
            window.isReleasedWhenClosed = false

            window.contentView = AreaSelectionOverlayView(captureService: self, screen: screen)
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }

        NSCursor.crosshair.push()
        didPushCrosshairCursor = true
    }

    // MARK: - Window Capture

    private func beginWindowCapture() {
        state = .capturing(.window)
        installEscapeMonitors()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.001)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = false
            window.hasShadow = false
            window.acceptsMouseMovedEvents = true
            window.isReleasedWhenClosed = false

            window.contentView = WindowCaptureOverlayView(captureService: self, screen: screen)
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }
    }

    // MARK: - Full Screen Capture

    private func beginFullScreenCapture() {
        state = .capturing(.fullScreen)
        installEscapeMonitors()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.001)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = false
            window.hasShadow = false
            window.acceptsMouseMovedEvents = true
            window.isReleasedWhenClosed = false

            window.contentView = FullScreenCaptureOverlayView(captureService: self, screen: screen)
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }
    }

    // MARK: - Capture Execution

    func captureArea(rect: CGRect, screen: NSScreen) {
        dismissOverlays()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let cgRect = self.viewRectToGlobalCG(rect, on: screen)

            guard let cgImage = CGWindowListCreateImage(
                cgRect,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
            ) else {
                self.state = .idle
                return
            }

            let image = NSImage(cgImage: cgImage, size: NSSize(width: rect.width, height: rect.height))
            self.handleCapturedImage(image)
        }
    }

    func captureWindow(windowID: CGWindowID) {
        dismissOverlays()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let cgImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming, .bestResolution]
            ) else {
                self.state = .idle
                return
            }

            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            self.handleCapturedImage(image)
        }
    }

    func captureFullScreen(screen: NSScreen) {
        dismissOverlays()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let displayID = self.displayIDForScreen(screen)
            guard let cgImage = CGDisplayCreateImage(displayID) else {
                self.state = .idle
                return
            }

            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            self.handleCapturedImage(image)
        }
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

    // MARK: - Coordinate Conversion

    private func viewRectToGlobalCG(_ viewRect: CGRect, on screen: NSScreen) -> CGRect {
        // SwiftUI view coordinates: origin top-left, Y increases downward
        // CG global coordinates: origin top-left of primary display, Y increases downward
        guard let primaryScreen = NSScreen.main ?? NSScreen.screens.first else { return viewRect }
        let primaryHeight = primaryScreen.frame.height

        let screenCGOriginX = screen.frame.origin.x
        let screenCGOriginY = primaryHeight - screen.frame.origin.y - screen.frame.height

        return CGRect(
            x: screenCGOriginX + viewRect.origin.x,
            y: screenCGOriginY + viewRect.origin.y,
            width: viewRect.width,
            height: viewRect.height
        )
    }

    private func displayIDForScreen(_ screen: NSScreen) -> CGDirectDisplayID {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        return screenNumber ?? CGMainDisplayID()
    }

}

extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}

private struct OfficialCaptureToolbarView: View {
    @ObservedObject var captureService: CaptureService

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                toolbarContent
            }
            .padding(4)
        } else {
            toolbarContent
                .padding(4)
        }
    }

    private var toolbarContent: some View {
        HStack(spacing: 10) {
            CaptureGlassModeButton(
                title: "Area",
                systemImage: "selection.pin.in.out",
                isSelected: captureService.selectedMode == .area
            ) {
                captureService.selectMode(.area)
            }

            CaptureGlassModeButton(
                title: "Window",
                systemImage: "macwindow",
                isSelected: captureService.selectedMode == .window
            ) {
                captureService.selectMode(.window)
            }

            CaptureGlassModeButton(
                title: "Screen",
                systemImage: "display",
                isSelected: captureService.selectedMode == .fullScreen
            ) {
                captureService.selectMode(.fullScreen)
            }
        }
    }
}

private struct CaptureGlassModeButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .frame(width: 130, height: 42)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(OfficialGlassControlModifier(isSelected: isSelected))
    }
}

private struct OfficialGlassControlModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    (isSelected ? Glass.regular.tint(.white.opacity(0.12)) : Glass.regular).interactive(),
                    in: Capsule()
                )
        } else {
            content
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(isSelected ? 1 : 0.86)
                )
                .overlay {
                    Capsule()
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(isSelected ? 0.55 : 0.32), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
    }
}

private struct CapturePreviewGlassView: View {
    let captureService: CaptureService
    let result: CaptureResult
    let onDismiss: () -> Void
    @State private var temporaryPreviewURL: URL?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                openInPreview()
            } label: {
                Image(nsImage: result.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 292, height: 184)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Text(result.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: 220, alignment: .leading)
                            .modifier(PreviewGlassCapsule())
                            .padding(10)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 0.75)
                    }
                    .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .help("Open in Preview")

            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    actionButtons
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
            } else {
                actionButtons
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
        }
        .frame(width: 316, height: 226)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            PreviewGlassButton(systemImage: "eye", help: "Open in Preview") {
                openInPreview()
            }
            PreviewGlassButton(systemImage: "square.and.arrow.down", help: "Save As") {
                captureService.saveAs()
            }
            PreviewGlassButton(systemImage: "pencil", help: "Rename") {
                rename()
            }
            PreviewGlassButton(systemImage: "trash", help: "Delete") {
                captureService.deleteFile()
                onDismiss()
            }
            PreviewGlassButton(systemImage: "xmark", help: "Close") {
                onDismiss()
            }
        }
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

private struct PreviewGlassButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .modifier(PreviewGlassCircle())
    }
}

private struct PreviewGlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.36), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
    }
}

private struct PreviewGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

private final class AreaSelectionOverlayView: NSView {
    private weak var captureService: CaptureService?
    private let screen: NSScreen
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var isFlipped: Bool { true }

    init(captureService: CaptureService, screen: NSScreen) {
        self.captureService = captureService
        self.screen = screen
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width > 3, rect.height > 3 else {
            captureService?.cancelCapture()
            return
        }
        captureService?.captureArea(rect: rect, screen: screen)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(selectionRect == nil ? 0.15 : 0.35).setFill()
        if let selectionRect {
            let dimPath = NSBezierPath(rect: bounds)
            dimPath.append(NSBezierPath(rect: selectionRect))
            dimPath.windingRule = .evenOdd
            dimPath.fill()

            NSColor.white.setStroke()
            let selectionPath = NSBezierPath(rect: selectionRect)
            selectionPath.lineWidth = 1.5
            selectionPath.stroke()

            if selectionRect.width > 40, selectionRect.height > 20 {
                drawSizeLabel(for: selectionRect)
            }
        } else {
            NSBezierPath(rect: bounds).fill()
        }
    }

    private func drawSizeLabel(for rect: CGRect) {
        let label = "\(Int(rect.width * screen.backingScaleFactor)) x \(Int(rect.height * screen.backingScaleFactor))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = label.size(withAttributes: attributes)
        let labelRect = CGRect(
            x: rect.midX - (textSize.width + 16) / 2,
            y: min(rect.maxY + 10, bounds.maxY - textSize.height - 10),
            width: textSize.width + 16,
            height: textSize.height + 6
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 8, yRadius: 8).fill()
        label.draw(at: CGPoint(x: labelRect.minX + 8, y: labelRect.minY + 3), withAttributes: attributes)
    }
}

private final class WindowCaptureOverlayView: NSView {
    private weak var captureService: CaptureService?
    private let screen: NSScreen
    private var hoveredWindowID: CGWindowID?
    private var hoveredWindowFrame: CGRect = .zero
    private var trackingAreaRef: NSTrackingArea?

    override var isFlipped: Bool { true }

    init(captureService: CaptureService, screen: NSScreen) {
        self.captureService = captureService
        self.screen = screen
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoveredWindow()
    }

    override func mouseExited(with event: NSEvent) {
        hoveredWindowID = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        updateHoveredWindow()
        if let hoveredWindowID {
            captureService?.captureWindow(windowID: hoveredWindowID)
        } else {
            captureService?.cancelCapture()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.15).setFill()
        NSBezierPath(rect: bounds).fill()

        guard hoveredWindowID != nil else { return }
        NSColor.clear.setFill()
        NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
        let path = NSBezierPath(roundedRect: hoveredWindowFrame, xRadius: 8, yRadius: 8)
        path.lineWidth = 3
        path.stroke()
    }

    private func updateHoveredWindow() {
        guard screen.frame.contains(NSEvent.mouseLocation),
              let match = WindowLookup.windowUnderCurrentMouse(excluding: ProcessInfo.processInfo.processIdentifier) else {
            hoveredWindowID = nil
            needsDisplay = true
            return
        }

        hoveredWindowID = match.id
        let screenOrigin = WindowLookup.cgOrigin(for: screen)
        hoveredWindowFrame = CGRect(
            x: match.frame.origin.x - screenOrigin.x,
            y: match.frame.origin.y - screenOrigin.y,
            width: match.frame.width,
            height: match.frame.height
        )
        needsDisplay = true
    }
}

private final class FullScreenCaptureOverlayView: NSView {
    private weak var captureService: CaptureService?
    private let screen: NSScreen
    private var isHovered = false
    private var trackingAreaRef: NSTrackingArea?

    override var isFlipped: Bool { true }

    init(captureService: CaptureService, screen: NSScreen) {
        self.captureService = captureService
        self.screen = screen
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        captureService?.captureFullScreen(screen: screen)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(isHovered ? 0.05 : 0.2).setFill()
        NSBezierPath(rect: bounds).fill()

        if isHovered {
            NSColor.systemBlue.withAlphaComponent(0.75).setStroke()
            let border = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
            border.lineWidth = 4
            border.stroke()
        }

        let label = "Click to capture"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(isHovered ? 0.9 : 0.55)
        ]
        let size = label.size(withAttributes: attributes)
        label.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}

private enum WindowLookup {
    static func windowUnderCurrentMouse(excluding processID: Int32) -> (id: CGWindowID, frame: CGRect)? {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        let mouseLocation = NSEvent.mouseLocation
        let cgPoint = CGPoint(x: mouseLocation.x, y: mainScreen.frame.height - mouseLocation.y)
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowList {
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  ownerPID != processID else {
                continue
            }

            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            guard frame.width > 20, frame.height > 20, frame.contains(cgPoint) else { continue }
            return (windowID, frame)
        }

        return nil
    }

    static func cgOrigin(for screen: NSScreen) -> CGPoint {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else {
            return screen.frame.origin
        }

        return CGPoint(
            x: screen.frame.origin.x,
            y: mainScreen.frame.height - screen.frame.origin.y - screen.frame.height
        )
    }
}
