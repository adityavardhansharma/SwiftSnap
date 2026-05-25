import AppKit
import CoreGraphics

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    let frame: CGRect
    let layer: Int
    let isOnScreen: Bool

    static func allWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap { dict -> WindowInfo? in
            guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  width > 1, height > 1
            else { return nil }

            let ownerName = dict[kCGWindowOwnerName as String] as? String ?? ""
            let name = dict[kCGWindowName as String] as? String ?? ""
            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? false

            if ownerName == "SwiftSnap" { return nil }
            if ownerName == "Window Server" { return nil }
            if layer != 0 { return nil }

            let frame = CGRect(x: x, y: y, width: width, height: height)
            return WindowInfo(
                id: windowID,
                name: name,
                ownerName: ownerName,
                frame: frame,
                layer: layer,
                isOnScreen: isOnScreen
            )
        }
    }

    static func windowAt(point: CGPoint) -> WindowInfo? {
        let windows = allWindows()
        return windows.first { $0.frame.contains(point) }
    }
}
