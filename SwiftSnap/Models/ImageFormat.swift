import Foundation

enum ImageFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpg = "JPG"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpg: return "jpg"
        }
    }

    var utType: String {
        switch self {
        case .png: return "public.png"
        case .jpg: return "public.jpeg"
        }
    }
}
