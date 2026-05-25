import AppKit

final class SaveService {
    static let shared = SaveService()

    private init() {}

    func save(_ image: NSImage, settings: AppSettings) -> URL? {
        guard settings.saveEnabled else { return nil }

        let folder = settings.saveFolder
        let filename = generateFilename(settings: settings)
        let ext = settings.imageFormat.fileExtension
        let url = folder.appendingPathComponent("\(filename).\(ext)")

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData)
        else { return nil }

        let data: Data?
        switch settings.imageFormat {
        case .png:
            data = bitmapRep.representation(using: .png, properties: [:])
        case .jpg:
            data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        }

        guard let imageData = data else { return nil }

        do {
            try imageData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func generateFilename(settings: AppSettings) -> String {
        switch settings.filenameFormat {
        case .dateTime:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
            return "SwiftSnap \(formatter.string(from: Date()))"

        case .sequential:
            let count = UserDefaults.standard.integer(forKey: "screenshotCount") + 1
            UserDefaults.standard.set(count, forKey: "screenshotCount")
            return String(format: "SwiftSnap-%03d", count)

        case .custom:
            let count = UserDefaults.standard.integer(forKey: "screenshotCount") + 1
            UserDefaults.standard.set(count, forKey: "screenshotCount")
            return String(format: "%@-%03d", settings.customPrefix, count)
        }
    }
}
