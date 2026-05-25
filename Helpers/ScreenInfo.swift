import AppKit

struct ScreenInfo {
    static var allScreens: [NSScreen] {
        NSScreen.screens
    }

    static var mainScreen: NSScreen? {
        NSScreen.main
    }

    static func screenAt(point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    static func screenContaining(mouseLocation: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }

    static var fullFrame: NSRect {
        var frame = NSRect.zero
        for screen in NSScreen.screens {
            frame = frame.union(screen.frame)
        }
        return frame
    }
}
