import SwiftUI
import AppKit

struct WindowHighlightOverlay: View {
    @ObservedObject var captureService: CaptureService
    let screen: NSScreen

    @State private var hoveredWindowID: CGWindowID?
    @State private var hoveredWindowFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.15)

                // Highlight for hovered window
                if hoveredWindowID != nil {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.8), .blue.opacity(0.4)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 3
                                )
                        }
                        .frame(width: hoveredWindowFrame.width, height: hoveredWindowFrame.height)
                        .position(x: hoveredWindowFrame.midX, y: hoveredWindowFrame.midY)
                        .shadow(color: .blue.opacity(0.3), radius: 10)
                        .allowsHitTesting(false)

                    // Cutout
                    Rectangle()
                        .blendMode(.destinationOut)
                        .frame(width: hoveredWindowFrame.width - 4, height: hoveredWindowFrame.height - 4)
                        .position(x: hoveredWindowFrame.midX, y: hoveredWindowFrame.midY)
                        .allowsHitTesting(false)
                }

                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            updateHoveredWindow(at: location, in: geometry.size)
                        case .ended:
                            hoveredWindowID = nil
                        }
                    }
                    .onTapGesture {
                        if let windowID = hoveredWindowID ?? windowIDAtCurrentMouseLocation() {
                            captureService.captureWindow(windowID: windowID)
                        } else {
                            captureService.cancelCapture()
                        }
                    }
            }
            .compositingGroup()
        }
        .ignoresSafeArea()
    }

    private func updateHoveredWindow(at point: CGPoint, in size: CGSize) {
        guard screen.frame.contains(NSEvent.mouseLocation) else {
            hoveredWindowID = nil
            return
        }

        guard let match = windowUnderCurrentMouse() else {
            hoveredWindowID = nil
            return
        }

        hoveredWindowID = match.id
        let screenOrigin = cgOrigin(for: screen)
        hoveredWindowFrame = CGRect(
            x: match.frame.origin.x - screenOrigin.x,
            y: match.frame.origin.y - screenOrigin.y,
            width: match.frame.width,
            height: match.frame.height
        )
    }

    private func windowIDAtCurrentMouseLocation() -> CGWindowID? {
        guard screen.frame.contains(NSEvent.mouseLocation) else { return nil }
        return windowUnderCurrentMouse()?.id
    }

    private func windowUnderCurrentMouse() -> (id: CGWindowID, frame: CGRect)? {
        let screenPoint = NSEvent.mouseLocation
        let cgPoint = cgPoint(fromAppKitPoint: screenPoint)

        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowList {
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  ownerPID != ProcessInfo.processInfo.processIdentifier else {
                continue
            }

            let windowRect = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            guard windowRect.width > 20, windowRect.height > 20 else { continue }

            if windowRect.contains(cgPoint) {
                return (windowID, windowRect)
            }
        }

        return nil
    }

    private func cgPoint(fromAppKitPoint point: CGPoint) -> CGPoint {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else { return point }
        return CGPoint(x: point.x, y: mainScreen.frame.height - point.y)
    }

    private func cgOrigin(for screen: NSScreen) -> CGPoint {
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else {
            return screen.frame.origin
        }

        return CGPoint(
            x: screen.frame.origin.x,
            y: mainScreen.frame.height - screen.frame.origin.y - screen.frame.height
        )
    }
}
