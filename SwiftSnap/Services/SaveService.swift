import AppKit
import UniformTypeIdentifiers

final class SaveService {
    private let settingsStore: SettingsStore
    private let fileManager: FileManager

    init(settingsStore: SettingsStore, fileManager: FileManager = .default) {
        self.settingsStore = settingsStore
        self.fileManager = fileManager
    }

    func save(image: NSImage, filename: String? = nil) -> URL? {
        guard let folder = destinationFolder() else { return nil }

        let name = sanitizedFilename(filename ?? settingsStore.generateFilename())
        let ext = settingsStore.imageFormat.fileExtension
        let url = uniqueURL(in: folder, baseName: name, extension: ext)

        guard let data = imageData(from: image) else { return nil }

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func destinationFolder() -> URL? {
        if let folder = settingsStore.saveFolderURL {
            return folder
        }

        guard let desktop = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            return nil
        }

        let folder = desktop.appendingPathComponent("SwiftSnap", isDirectory: true)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        } catch {
            return desktop
        }
    }

    func saveAs(image: NSImage, suggestedName: String? = nil) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = settingsStore.imageFormat == .png
            ? [UTType.png]
            : [UTType.jpeg]
        let suggestedBaseName = sanitizedFilename((suggestedName ?? settingsStore.generateFilename()).deletingKnownImageExtension)
        panel.nameFieldStringValue = "\(suggestedBaseName).\(settingsStore.imageFormat.fileExtension)"
        panel.canCreateDirectories = true
        panel.level = .floating

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        guard let data = imageData(from: image) else { return nil }

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func rename(at url: URL, to newName: String) -> URL? {
        let ext = url.pathExtension
        let baseName = sanitizedFilename(newName.deletingKnownImageExtension)
        let newURL = uniqueURL(in: url.deletingLastPathComponent(), baseName: baseName, extension: ext, excluding: url)
        do {
            try fileManager.moveItem(at: url, to: newURL)
            return newURL
        } catch {
            return nil
        }
    }

    func delete(at url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    private func imageData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else { return nil }

        switch settingsStore.imageFormat {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
        }
    }

    private func sanitizedFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        let cleaned = name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "SwiftSnap" : cleaned
    }

    private func uniqueURL(in folder: URL, baseName: String, extension ext: String, excluding excludedURL: URL? = nil) -> URL {
        var candidate = folder.appendingPathComponent("\(baseName).\(ext)")
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path), candidate != excludedURL {
            candidate = folder.appendingPathComponent("\(baseName) \(suffix).\(ext)")
            suffix += 1
        }

        return candidate
    }
}

private extension String {
    var deletingKnownImageExtension: String {
        let url = URL(fileURLWithPath: self)
        let ext = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg"].contains(ext) else { return self }
        return url.deletingPathExtension().lastPathComponent
    }
}
