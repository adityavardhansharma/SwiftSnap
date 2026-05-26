import XCTest
@testable import SwiftSnap

final class SaveServiceTests: XCTestCase {
    var settingsStore: SettingsStore!
    var saveService: SaveService!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "filenameFormat")
        settingsStore = SettingsStore()
        saveService = SaveService(settingsStore: settingsStore)
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        settingsStore.saveFolderURL = tempDir
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSavePNG() {
        settingsStore.imageFormat = .png
        let image = createTestImage()

        let url = saveService.save(image: image, filename: "test_save")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.pathExtension == "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url!.path))
    }

    func testSaveJPG() {
        settingsStore.imageFormat = .jpg
        let image = createTestImage()

        let url = saveService.save(image: image, filename: "test_save_jpg")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.pathExtension == "jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url!.path))
    }

    func testSaveWithDefaultFilename() {
        let image = createTestImage()
        let url = saveService.save(image: image)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.lastPathComponent.hasPrefix("SwiftSnap"))
    }

    func testRename() {
        let image = createTestImage()
        guard let originalURL = saveService.save(image: image, filename: "original") else {
            XCTFail("Failed to save initial file")
            return
        }

        let newURL = saveService.rename(at: originalURL, to: "renamed")
        XCTAssertNotNil(newURL)
        XCTAssertEqual(newURL?.deletingPathExtension().lastPathComponent, "renamed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL!.path))
    }

    func testDelete() {
        let image = createTestImage()
        guard let url = saveService.save(image: image, filename: "to_delete") else {
            XCTFail("Failed to save file")
            return
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let deleted = saveService.delete(at: url)
        XCTAssertTrue(deleted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testSaveWithNoFolderUsesDefaultLocation() {
        settingsStore.saveFolderURL = nil
        let image = createTestImage()
        let url = saveService.save(image: image)
        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url!.path))
        try? FileManager.default.removeItem(at: url!)
    }

    private func createTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 100, height: 100))
        image.unlockFocus()
        return image
    }
}
