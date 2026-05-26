import XCTest
@testable import SwiftSnap

final class SettingsStoreTests: XCTestCase {
    var settingsStore: SettingsStore!

    override func setUp() {
        super.setUp()
        let suiteName = "com.swiftsnap.test.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        settingsStore = SettingsStore()
    }

    func testDefaultValues() {
        let store = SettingsStore()
        XCTAssertEqual(store.imageFormat, .png)
        XCTAssertTrue(store.showNotification)
        XCTAssertTrue(store.captureSound)
        XCTAssertEqual(store.filenameFormat, "SwiftSnap {date} at {time}")
    }

    func testClipboardOnlyPersistence() {
        settingsStore.clipboardOnly = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "clipboardOnly"))
    }

    func testImageFormatPersistence() {
        settingsStore.imageFormat = .jpg
        XCTAssertEqual(UserDefaults.standard.string(forKey: "imageFormat"), "JPG")
    }

    func testShowNotificationPersistence() {
        settingsStore.showNotification = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "showNotification"))
    }

    func testCaptureSoundPersistence() {
        settingsStore.captureSound = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "captureSound"))
    }

    func testFilenameFormatPersistence() {
        settingsStore.filenameFormat = "Test {date}"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "filenameFormat"), "Test {date}")
    }

    func testOnboardingCompletionPersistence() {
        settingsStore.hasCompletedOnboarding = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
}
