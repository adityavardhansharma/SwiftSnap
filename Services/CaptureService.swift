import AppKit
import ScreenCaptureKit

final class CaptureService {
    static let shared = CaptureService()

    private init() {}

    func captureArea(rect: CGRect) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            let display = content.displays.first(where: { $0.frame.intersects(rect) })
                ?? content.displays.first
            guard let display else { return nil }

            let excludedWindows = content.windows.filter {
                $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

            let relativeRect = CGRect(
                x: rect.origin.x - display.frame.origin.x,
                y: rect.origin.y - display.frame.origin.y,
                width: rect.width,
                height: rect.height
            )

            let scaleFactor = await MainActor.run {
                NSScreen.main?.backingScaleFactor ?? 2
            }

            let config = SCStreamConfiguration()
            config.sourceRect = relativeRect
            config.width = Int(rect.width * scaleFactor)
            config.height = Int(rect.height * scaleFactor)
            config.showsCursor = false
            config.captureResolution = .best

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
            return NSImage(cgImage: cgImage, size: size)
        } catch {
            return nil
        }
    }

    func captureWindow(windowID: CGWindowID) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)

            let scaleFactor = await MainActor.run {
                NSScreen.main?.backingScaleFactor ?? 2
            }

            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width * scaleFactor)
            config.height = Int(window.frame.height * scaleFactor)
            config.showsCursor = false
            config.captureResolution = .best

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
            return NSImage(cgImage: cgImage, size: size)
        } catch {
            return nil
        }
    }

    func captureFullScreen(screen: NSScreen) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let displayID = displayIDForScreen(screen)

            guard let display = content.displays.first(where: { $0.displayID == displayID })
                ?? content.displays.first
            else { return nil }

            let excludedWindows = content.windows.filter {
                $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

            let scaleFactor = await MainActor.run {
                screen.backingScaleFactor
            }

            let config = SCStreamConfiguration()
            config.width = Int(CGFloat(display.width) * scaleFactor)
            config.height = Int(CGFloat(display.height) * scaleFactor)
            config.showsCursor = false
            config.captureResolution = .best

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
            return NSImage(cgImage: cgImage, size: size)
        } catch {
            return nil
        }
    }

    private func displayIDForScreen(_ screen: NSScreen) -> CGDirectDisplayID {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
        return screenNumber as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}
