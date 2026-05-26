import XCTest
@testable import SwiftSnap

final class RecentCapturesManagerTests: XCTestCase {
    var manager: RecentCapturesManager!

    override func setUp() {
        super.setUp()
        manager = RecentCapturesManager()
    }

    func testAddCapture() {
        let image = createTestImage()
        let capture = CaptureResult(image: image)

        manager.add(capture)

        let expectation = XCTestExpectation(description: "Capture added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.manager.recentCaptures.count, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMaxCaptures() {
        let expectation = XCTestExpectation(description: "All captures added")

        for i in 0..<7 {
            let image = createTestImage()
            let capture = CaptureResult(image: image)
            manager.add(capture)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertEqual(self.manager.recentCaptures.count, 5, "Should not exceed 5 captures")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testNewestFirst() {
        let expectation = XCTestExpectation(description: "Order checked")

        let image1 = createTestImage()
        var capture1 = CaptureResult(image: image1)
        capture1.displayName = "First"
        manager.add(capture1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let image2 = self.createTestImage()
            var capture2 = CaptureResult(image: image2)
            capture2.displayName = "Second"
            self.manager.add(capture2)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                XCTAssertEqual(self.manager.recentCaptures.first?.displayName, "Second")
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRemoveCapture() {
        let expectation = XCTestExpectation(description: "Capture removed")

        let image = createTestImage()
        let capture = CaptureResult(image: image)
        manager.add(capture)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.manager.remove(id: capture.id)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(self.manager.recentCaptures.count, 0)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testUpdateSavedURL() {
        let expectation = XCTestExpectation(description: "URL updated")

        let image = createTestImage()
        let capture = CaptureResult(image: image)
        manager.add(capture)

        let testURL = URL(fileURLWithPath: "/tmp/test.png")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.manager.updateSavedURL(id: capture.id, url: testURL)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(self.manager.recentCaptures.first?.savedURL, testURL)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
    }

    private func createTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 50, height: 50))
        image.lockFocus()
        NSColor.gray.drawSwatch(in: NSRect(x: 0, y: 0, width: 50, height: 50))
        image.unlockFocus()
        return image
    }
}
