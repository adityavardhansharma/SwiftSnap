import AppKit

final class OverlayPanel: NSPanel {
    private let selectionView: AreaSelectionView

    init(
        screen: NSScreen,
        onSelection: @escaping (CGRect, NSScreen) -> Void,
        onCancel: @escaping () -> Void
    ) {
        selectionView = AreaSelectionView(
            screenFrame: screen.frame,
            onSelection: { rect in onSelection(rect, screen) },
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
        self.contentView = selectionView
    }
}

final class AreaSelectionView: NSView {
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var isDragging = false
    private let screenFrame: NSRect

    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    init(
        screenFrame: NSRect,
        onSelection: @escaping (CGRect) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.screenFrame = screenFrame
        self.onSelection = onSelection
        self.onCancel = onCancel
        super.init(frame: screenFrame)
        addCrosshairCursor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func addCrosshairCursor() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging,
              let start = startPoint,
              let end = currentPoint
        else { return }

        isDragging = false

        let rect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        if rect.width > 3 && rect.height > 3 {
            let globalRect = NSRect(
                x: screenFrame.origin.x + rect.origin.x,
                y: screenFrame.origin.y + rect.origin.y,
                width: rect.width,
                height: rect.height
            )
            onSelection?(globalRect)
        }

        startPoint = nil
        currentPoint = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Semi-transparent dark overlay
        NSColor(white: 0, alpha: 0.3).setFill()
        dirtyRect.fill()

        guard isDragging,
              let start = startPoint,
              let current = currentPoint
        else { return }

        let selectionRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        // Clear the selection area
        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        // Draw selection border
        let borderPath = NSBezierPath(roundedRect: selectionRect, xRadius: 2, yRadius: 2)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        borderPath.lineWidth = 1.5
        borderPath.stroke()

        // Draw subtle inner glow
        let innerGlow = NSBezierPath(roundedRect: selectionRect.insetBy(dx: 1, dy: 1), xRadius: 1, yRadius: 1)
        NSColor.white.withAlphaComponent(0.15).setStroke()
        innerGlow.lineWidth = 0.5
        innerGlow.stroke()

        // Draw dimension label
        let width = Int(selectionRect.width)
        let height = Int(selectionRect.height)
        let dimensionText = "\(width) × \(height)"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]

        let textSize = (dimensionText as NSString).size(withAttributes: attributes)
        let textRect = NSRect(
            x: selectionRect.midX - textSize.width / 2 - 8,
            y: selectionRect.origin.y - textSize.height - 12,
            width: textSize.width + 16,
            height: textSize.height + 6
        )

        if textRect.origin.y > 0 {
            let bgPath = NSBezierPath(roundedRect: textRect, xRadius: 6, yRadius: 6)
            NSColor(white: 0, alpha: 0.7).setFill()
            bgPath.fill()

            let textOrigin = NSPoint(
                x: textRect.origin.x + 8,
                y: textRect.origin.y + 3
            )
            (dimensionText as NSString).draw(at: textOrigin, withAttributes: attributes)
        }
    }
}
