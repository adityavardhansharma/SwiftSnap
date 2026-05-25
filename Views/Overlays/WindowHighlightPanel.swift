import AppKit

final class WindowHighlightPanel: NSPanel {
    private let highlightView: WindowHighlightView

    init(
        screen: NSScreen,
        onWindowSelected: @escaping (CGWindowID) -> Void,
        onCancel: @escaping () -> Void
    ) {
        highlightView = WindowHighlightView(
            screenFrame: screen.frame,
            onWindowSelected: onWindowSelected,
            onCancel: onCancel
        )

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .statusBar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = highlightView
    }
}

final class WindowHighlightView: NSView {
    private var hoveredWindow: WindowInfo?
    private var mouseTrackingTimer: Timer?
    private let screenFrame: NSRect

    var onWindowSelected: ((CGWindowID) -> Void)?
    var onCancel: (() -> Void)?

    init(
        screenFrame: NSRect,
        onWindowSelected: @escaping (CGWindowID) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.screenFrame = screenFrame
        self.onWindowSelected = onWindowSelected
        self.onCancel = onCancel
        super.init(frame: screenFrame)

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)

        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateHoveredWindow()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        mouseTrackingTimer?.invalidate()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoveredWindow()
    }

    override func mouseDown(with event: NSEvent) {
        if let windowID = hoveredWindow?.id {
            onWindowSelected?(windowID)
        }
    }

    private func updateHoveredWindow() {
        let mouseLocation = NSEvent.mouseLocation
        let cgPoint = CGPoint(
            x: mouseLocation.x,
            y: NSScreen.screens[0].frame.height - mouseLocation.y
        )

        let newHovered = WindowInfo.windowAt(point: cgPoint)
        if newHovered?.id != hoveredWindow?.id {
            hoveredWindow = newHovered
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.2).setFill()
        dirtyRect.fill()

        guard let window = hoveredWindow else { return }

        // Convert CG coordinates to NS coordinates
        let mainScreenHeight = NSScreen.screens[0].frame.height
        let nsRect = NSRect(
            x: window.frame.origin.x - screenFrame.origin.x,
            y: mainScreenHeight - window.frame.origin.y - window.frame.height - screenFrame.origin.y,
            width: window.frame.width,
            height: window.frame.height
        )

        // Draw highlight
        let highlightPath = NSBezierPath(roundedRect: nsRect, xRadius: 8, yRadius: 8)
        NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        highlightPath.fill()

        NSColor.controlAccentColor.withAlphaComponent(0.6).setStroke()
        highlightPath.lineWidth = 2.5
        highlightPath.stroke()

        // Draw window name label
        let labelText = window.ownerName.isEmpty ? "Window" : window.ownerName
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = (labelText as NSString).size(withAttributes: attributes)
        let labelRect = NSRect(
            x: nsRect.midX - textSize.width / 2 - 10,
            y: nsRect.midY - textSize.height / 2 - 4,
            width: textSize.width + 20,
            height: textSize.height + 8
        )

        let labelBg = NSBezierPath(roundedRect: labelRect, xRadius: 8, yRadius: 8)
        NSColor(white: 0, alpha: 0.65).setFill()
        labelBg.fill()

        let textOrigin = NSPoint(
            x: labelRect.origin.x + 10,
            y: labelRect.origin.y + 4
        )
        (labelText as NSString).draw(at: textOrigin, withAttributes: attributes)
    }
}
