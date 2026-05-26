import XCTest
@testable import SwiftSnap

final class CaptureServiceTests: XCTestCase {
    var captureService: CaptureService!
    var clipboardService: ClipboardService!
    var settingsStore: SettingsStore!
    var recentCapturesManager: RecentCapturesManager!

    override func setUp() {
        super.setUp()
        settingsStore = SettingsStore()
        clipboardService = ClipboardService()
        let saveService = SaveService(settingsStore: settingsStore)
        recentCapturesManager = RecentCapturesManager()
        captureService = CaptureService(
            clipboardService: clipboardService,
            saveService: saveService,
            settingsStore: settingsStore,
            recentCapturesManager: recentCapturesManager
        )
    }

    func testInitialState() {
        if case .idle = captureService.state {
            // expected
        } else {
            XCTFail("Initial state should be idle")
        }
    }

    func testDefaultMode() {
        XCTAssertEqual(captureService.selectedMode, .area)
    }

    func testStartCapture() {
        captureService.startCapture()
        if case .toolbar = captureService.state {
            // expected
        } else {
            XCTFail("State should be toolbar after startCapture")
        }
    }

    func testCancelCapture() {
        captureService.startCapture()
        captureService.cancelCapture()
        if case .idle = captureService.state {
            // expected
        } else {
            XCTFail("State should be idle after cancel")
        }
    }

    func testHandleCapturedImageCopiesClipboard() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 100, height: 100))
        image.unlockFocus()

        settingsStore.clipboardOnly = true
        captureService.handleCapturedImage(image)

        XCTAssertNotNil(captureService.currentResult)
        XCTAssertTrue(clipboardService.hasImage())
    }

    func testHandleCapturedImageAddsToRecents() {
        let image = NSImage(size: NSSize(width: 50, height: 50))
        image.lockFocus()
        NSColor.blue.drawSwatch(in: NSRect(x: 0, y: 0, width: 50, height: 50))
        image.unlockFocus()

        settingsStore.clipboardOnly = true
        captureService.handleCapturedImage(image)

        let expectation = XCTestExpectation(description: "Recent captures updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.recentCapturesManager.recentCaptures.count, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testCaptureModes() {
        XCTAssertEqual(CaptureMode.allCases.count, 3)
        XCTAssertEqual(CaptureMode.area.systemImage, "crop")
        XCTAssertEqual(CaptureMode.window.systemImage, "macwindow")
        XCTAssertEqual(CaptureMode.fullScreen.systemImage, "rectangle.inset.filled")
    }
}
