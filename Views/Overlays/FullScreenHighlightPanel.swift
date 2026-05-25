import AppKit

final class FullScreenHighlightPanel: NSPanel {
    private let highlightView: FullScreenHighlightView

    init(
        screen: NSScreen,
        onScreenSelected: @escaping (NSScreen) -> Void,
        onCancel: @escaping () -> Void
    ) {
        highlightView = FullScreenHighlightView(
            screen: screen,
            onScreenSelected: onScreenSelected,
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

final class FullScreenHighlightView: NSView {
    private let targetScreen: NSScreen
    private var isHovered = false
    private let isMultiMonitor: Bool

    var onScreenSelected: ((NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    init(
        screen: NSScreen,
        onScreenSelected: @escaping (NSScreen) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.targetScreen = screen
        self.isMultiMonitor = NSScreen.screens.count > 1
        self.onScreenSelected = onScreenSelected
        self.onCancel = onCancel
        super.init(frame: screen.frame)

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
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
        onScreenSelected?(targetScreen)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isMultiMonitor {
            if isHovered {
                NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
                bounds.fill()

                let border = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
                NSColor.controlAccentColor.withAlphaComponent(0.5).setStroke()
                border.lineWidth = 3
                border.stroke()
            } else {
                NSColor(white: 0, alpha: 0.15).setFill()
                bounds.fill()
            }

            // Display label
            let label = isHovered ? "Click to capture this display" : "Hover to select"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(isHovered ? 1.0 : 0.5),
            ]
            let textSize = (label as NSString).size(withAttributes: attributes)
            let bgRect = NSRect(
                x: bounds.midX - textSize.width / 2 - 16,
                y: bounds.midY - textSize.height / 2 - 8,
                width: textSize.width + 32,
                height: textSize.height + 16
            )
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 12, yRadius: 12)
            NSColor(white: 0, alpha: 0.6).setFill()
            bgPath.fill()

            let textOrigin = NSPoint(
                x: bounds.midX - textSize.width / 2,
                y: bounds.midY - textSize.height / 2
            )
            (label as NSString).draw(at: textOrigin, withAttributes: attributes)
        } else {
            NSColor.controlAccentColor.withAlphaComponent(0.08).setFill()
            bounds.fill()

            let label = "Click to capture screen"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
            let textSize = (label as NSString).size(withAttributes: attributes)
            let bgRect = NSRect(
                x: bounds.midX - textSize.width / 2 - 16,
                y: bounds.midY - textSize.height / 2 - 8,
                width: textSize.width + 32,
                height: textSize.height + 16
            )
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 12, yRadius: 12)
            NSColor(white: 0, alpha: 0.6).setFill()
            bgPath.fill()

            let textOrigin = NSPoint(
                x: bounds.midX - textSize.width / 2,
                y: bounds.midY - textSize.height / 2
            )
            (label as NSString).draw(at: textOrigin, withAttributes: attributes)
        }
    }
}
