import Foundation
import Combine
import ServiceManagement

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let saveFolder = "saveFolder"
        static let clipboardOnly = "clipboardOnly"
        static let imageFormat = "imageFormat"
        static let filenameFormat = "filenameFormat"
        static let launchAtStartup = "launchAtStartup"
        static let showNotification = "showNotification"
        static let captureSound = "captureSound"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    @Published var saveFolderURL: URL? {
        didSet {
            if let url = saveFolderURL {
                let bookmark = try? url.bookmarkData(options: .withSecurityScope)
                UserDefaults.standard.set(bookmark, forKey: Keys.saveFolder)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.saveFolder)
            }
        }
    }

    @Published var clipboardOnly: Bool {
        didSet { UserDefaults.standard.set(clipboardOnly, forKey: Keys.clipboardOnly) }
    }

    @Published var imageFormat: ImageFormat {
        didSet { UserDefaults.standard.set(imageFormat.rawValue, forKey: Keys.imageFormat) }
    }

    @Published var filenameFormat: String {
        didSet { UserDefaults.standard.set(filenameFormat, forKey: Keys.filenameFormat) }
    }

    @Published var launchAtStartup: Bool {
        didSet {
            UserDefaults.standard.set(launchAtStartup, forKey: Keys.launchAtStartup)
            updateLoginItem()
        }
    }

    @Published var showNotification: Bool {
        didSet { UserDefaults.standard.set(showNotification, forKey: Keys.showNotification) }
    }

    @Published var captureSound: Bool {
        didSet { UserDefaults.standard.set(captureSound, forKey: Keys.captureSound) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.clipboardOnly = defaults.bool(forKey: Keys.clipboardOnly)
        self.showNotification = defaults.object(forKey: Keys.showNotification) as? Bool ?? true
        self.captureSound = defaults.object(forKey: Keys.captureSound) as? Bool ?? true
        self.launchAtStartup = defaults.bool(forKey: Keys.launchAtStartup)
        self.filenameFormat = defaults.string(forKey: Keys.filenameFormat) ?? "SwiftSnap {date} at {time}"

        if let raw = defaults.string(forKey: Keys.imageFormat),
           let format = ImageFormat(rawValue: raw) {
            self.imageFormat = format
        } else {
            self.imageFormat = .png
        }

        if let bookmarkData = defaults.data(forKey: Keys.saveFolder) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                self.saveFolderURL = url
                if isStale, let bookmark = try? url.bookmarkData(options: .withSecurityScope) {
                    defaults.set(bookmark, forKey: Keys.saveFolder)
                }
            }
        }
    }

    func generateFilename() -> String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH.mm.ss"

        return filenameFormat
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: now))
            .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: now))
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtStartup {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                UserDefaults.standard.set(false, forKey: Keys.launchAtStartup)
                launchAtStartup = false
            }
        }
    }
}
