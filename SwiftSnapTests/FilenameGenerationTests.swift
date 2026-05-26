import XCTest
@testable import SwiftSnap

final class FilenameGenerationTests: XCTestCase {
    var settingsStore: SettingsStore!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "filenameFormat")
        settingsStore = SettingsStore()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "filenameFormat")
        super.tearDown()
    }

    func testDefaultFilenameContainsSwiftSnap() {
        let filename = settingsStore.generateFilename()
        XCTAssertTrue(filename.hasPrefix("SwiftSnap"), "Default filename should start with 'SwiftSnap'")
    }

    func testFilenameContainsDate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        let filename = settingsStore.generateFilename()
        XCTAssertTrue(filename.contains(dateString), "Filename should contain today's date")
    }

    func testFilenameContainsTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        let hourString = formatter.string(from: Date())

        let filename = settingsStore.generateFilename()
        XCTAssertTrue(filename.contains(hourString), "Filename should contain current hour")
    }

    func testCustomFilenameFormat() {
        settingsStore.filenameFormat = "Screenshot {date}"
        let filename = settingsStore.generateFilename()
        XCTAssertTrue(filename.hasPrefix("Screenshot"), "Custom format should be respected")
        XCTAssertFalse(filename.contains("{date}"), "Date token should be replaced")
    }

    func testFilenameFormatWithoutTokens() {
        settingsStore.filenameFormat = "MyScreenshot"
        let filename = settingsStore.generateFilename()
        XCTAssertEqual(filename, "MyScreenshot")
    }

    func testImageFormatExtensions() {
        XCTAssertEqual(ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageFormat.jpg.fileExtension, "jpg")
    }
}
