import AppKit
import SwiftUI

final class RecentCapturesManager: ObservableObject {
    static let shared = RecentCapturesManager()

    @Published var captures: [CaptureResult] = []

    private let maxCaptures = 5

    private init() {}

    func add(_ result: CaptureResult) {
        DispatchQueue.main.async {
            self.captures.insert(result, at: 0)
            if self.captures.count > self.maxCaptures {
                self.captures.removeLast()
            }
        }
    }

    func copyAgain(_ result: CaptureResult) {
        _ = ClipboardService.shared.copyToClipboard(result.image)
    }

    func revealInFinder(_ result: CaptureResult) {
        guard let url = result.savedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func clear() {
        captures.removeAll()
    }
}
