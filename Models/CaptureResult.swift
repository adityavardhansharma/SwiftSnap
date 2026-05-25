import AppKit
import Foundation

struct CaptureResult: Identifiable {
    let id: UUID
    let image: NSImage
    let timestamp: Date
    let mode: CaptureMode
    var savedURL: URL?

    var displayName: String {
        if let url = savedURL {
            return url.deletingPathExtension().lastPathComponent
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return "\(mode.label) – \(formatter.string(from: timestamp))"
    }

    var thumbnail: NSImage {
        let maxSize: CGFloat = 120
        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        thumb.unlockFocus()
        return thumb
    }

    init(image: NSImage, mode: CaptureMode, savedURL: URL? = nil) {
        self.id = UUID()
        self.image = image
        self.timestamp = Date()
        self.mode = mode
        self.savedURL = savedURL
    }
}
