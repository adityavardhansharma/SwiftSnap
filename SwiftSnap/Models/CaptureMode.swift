import Foundation

enum CaptureMode: String, CaseIterable, Identifiable {
    case area = "Area"
    case window = "Window"
    case fullScreen = "Full Screen"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .area: return "crop"
        case .window: return "macwindow"
        case .fullScreen: return "rectangle.inset.filled"
        }
    }

    var shortDescription: String {
        switch self {
        case .area: return "Drag to select area"
        case .window: return "Click a window"
        case .fullScreen: return "Click a display"
        }
    }
}
