import Foundation

enum CaptureMode: String, CaseIterable, Identifiable {
    case area
    case window
    case fullScreen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .area: return "Area"
        case .window: return "Window"
        case .fullScreen: return "Full Screen"
        }
    }

    var icon: String {
        switch self {
        case .area: return "crop"
        case .window: return "macwindow"
        case .fullScreen: return "display"
        }
    }
}
