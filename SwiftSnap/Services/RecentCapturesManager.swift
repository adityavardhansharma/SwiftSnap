import AppKit
import Combine

final class RecentCapturesManager: ObservableObject {
    @Published var recentCaptures: [CaptureResult] = []
    private let maxCaptures = 5

    func add(_ capture: CaptureResult) {
        DispatchQueue.main.async {
            self.recentCaptures.insert(capture, at: 0)
            if self.recentCaptures.count > self.maxCaptures {
                self.recentCaptures.removeLast()
            }
        }
    }

    func remove(id: UUID) {
        DispatchQueue.main.async {
            self.recentCaptures.removeAll { $0.id == id }
        }
    }

    func updateSavedURL(id: UUID, url: URL?) {
        DispatchQueue.main.async {
            if let index = self.recentCaptures.firstIndex(where: { $0.id == id }) {
                self.recentCaptures[index].savedURL = url
            }
        }
    }

    func updateMetadata(id: UUID, savedURL: URL?, displayName: String?) {
        DispatchQueue.main.async {
            if let index = self.recentCaptures.firstIndex(where: { $0.id == id }) {
                self.recentCaptures[index].savedURL = savedURL
                if let displayName {
                    self.recentCaptures[index].displayName = displayName
                }
            }
        }
    }

    func revealInFinder(_ capture: CaptureResult) {
        guard let url = capture.savedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
