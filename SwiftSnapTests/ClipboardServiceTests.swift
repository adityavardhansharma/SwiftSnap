import XCTest
@testable import SwiftSnap

final class ClipboardServiceTests: XCTestCase {
    var clipboardService: ClipboardService!

    override func setUp() {
        super.setUp()
        clipboardService = ClipboardService()
    }

    func testCopyToClipboard() {
        let image = createTestImage(width: 100, height: 100, color: .red)
        clipboardService.copyToClipboard(image)

        let pasteboard = NSPasteboard.general
        XCTAssertTrue(pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.tiff.rawValue]))
    }

    func testCopyToClipboardContainsPNG() {
        let image = createTestImage(width: 50, height: 50, color: .green)
        clipboardService.copyToClipboard(image)

        let pasteboard = NSPasteboard.general
        XCTAssertTrue(pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.png.rawValue]))
    }

    func testHasImageAfterCopy() {
        let image = createTestImage(width: 50, height: 50, color: .blue)
        clipboardService.copyToClipboard(image)
        XCTAssertTrue(clipboardService.hasImage())
    }

    func testCopyOverwritesPrevious() {
        let image1 = createTestImage(width: 100, height: 100, color: .red)
        let image2 = createTestImage(width: 200, height: 200, color: .blue)

        clipboardService.copyToClipboard(image1)
        clipboardService.copyToClipboard(image2)

        XCTAssertTrue(clipboardService.hasImage())
    }

    private func createTestImage(width: CGFloat, height: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.drawSwatch(in: NSRect(x: 0, y: 0, width: width, height: height))
        image.unlockFocus()
        return image
    }
}
