import AppKit
import Foundation

struct CaptureResult: Identifiable {
    let id = UUID()
    let image: NSImage
    let timestamp: Date
    var savedURL: URL?
    var displayName: String

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: timestamp)
    }

    init(image: NSImage, savedURL: URL? = nil, displayName: String? = nil) {
        self.image = image
        self.timestamp = Date()
        self.savedURL = savedURL
        self.displayName = displayName ?? "SwiftSnap \(CaptureResult.defaultFormatter.string(from: Date()))"
    }

    private static let defaultFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return f
    }()
}
