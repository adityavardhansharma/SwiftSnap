import Foundation

enum ImageFormat: String, CaseIterable, Identifiable {
    case png
    case jpg

    var id: String { rawValue }

    var fileExtension: String { rawValue }

    var label: String {
        switch self {
        case .png: return "PNG"
        case .jpg: return "JPEG"
        }
    }
}

enum FilenameFormat: String, CaseIterable, Identifiable {
    case dateTime = "datetime"
    case sequential = "sequential"
    case custom = "custom"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateTime: return "Date & Time"
        case .sequential: return "Sequential Number"
        case .custom: return "Custom Prefix"
        }
    }

    var example: String {
        switch self {
        case .dateTime: return "SwiftSnap 2024-01-15 at 14.30.22"
        case .sequential: return "SwiftSnap-001"
        case .custom: return "Screenshot-001"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var saveEnabled: Bool {
        didSet { UserDefaults.standard.set(saveEnabled, forKey: "saveEnabled") }
    }

    @Published var saveFolder: URL {
        didSet {
            if let data = try? saveFolder.bookmarkData(options: .withSecurityScope) {
                UserDefaults.standard.set(data, forKey: "saveFolderBookmark")
            }
        }
    }

    @Published var imageFormat: ImageFormat {
        didSet { UserDefaults.standard.set(imageFormat.rawValue, forKey: "imageFormat") }
    }

    @Published var filenameFormat: FilenameFormat {
        didSet { UserDefaults.standard.set(filenameFormat.rawValue, forKey: "filenameFormat") }
    }

    @Published var customPrefix: String {
        didSet { UserDefaults.standard.set(customPrefix, forKey: "customPrefix") }
    }

    @Published var launchAtStartup: Bool {
        didSet { UserDefaults.standard.set(launchAtStartup, forKey: "launchAtStartup") }
    }

    @Published var showNotifications: Bool {
        didSet { UserDefaults.standard.set(showNotifications, forKey: "showNotifications") }
    }

    @Published var playCaptureSound: Bool {
        didSet { UserDefaults.standard.set(playCaptureSound, forKey: "playCaptureSound") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    private init() {
        let defaults = UserDefaults.standard

        self.saveEnabled = defaults.object(forKey: "saveEnabled") as? Bool ?? true
        self.imageFormat = ImageFormat(rawValue: defaults.string(forKey: "imageFormat") ?? "") ?? .png
        self.filenameFormat = FilenameFormat(rawValue: defaults.string(forKey: "filenameFormat") ?? "") ?? .dateTime
        self.customPrefix = defaults.string(forKey: "customPrefix") ?? "Screenshot"
        self.launchAtStartup = defaults.bool(forKey: "launchAtStartup")
        self.showNotifications = defaults.object(forKey: "showNotifications") as? Bool ?? true
        self.playCaptureSound = defaults.object(forKey: "playCaptureSound") as? Bool ?? true
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")

        if let bookmarkData = defaults.data(forKey: "saveFolderBookmark") {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                bookmarkDataIsStale: &isStale
            ) {
                self.saveFolder = url
            } else {
                self.saveFolder = Self.defaultSaveFolder
            }
        } else {
            self.saveFolder = Self.defaultSaveFolder
        }
    }

    static var defaultSaveFolder: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }
}
