import Foundation

enum ModelPrecision: String {
    case full = "bf16", compact = "int8_convrot"
    var title: String { self == .full ? "Full precision" : "Memory efficient" }
    var downloadGB: String { self == .full ? "32.4" : "17.3" }
}

enum Quality: String, CaseIterable, Codable, Identifiable {
    case draft = "Entwurf", standard = "Standard", detail = "2K"
    var id: String { rawValue }
    var title: String { self == .draft ? "Draft" : rawValue }
    var referenceSize: Int { self == .draft ? 512 : (self == .detail ? 2048 : 1024) }
    var detail: String {
        switch self {
        case .draft: return "Small drafts · explore ideas faster"
        case .standard: return "A balance of detail and generation time"
        case .detail: return "High resolution · takes considerably longer"
        }
    }
}

enum Aspect: String, CaseIterable, Codable, Identifiable {
    case square = "1:1", landscape = "4:3", portrait = "3:4", photoLandscape = "3:2", photoPortrait = "2:3", wide = "16:9", story = "9:16"
    var id: String { rawValue }
    var symbol: String { self == .square ? "square" : (self == .portrait || self == .photoPortrait || self == .story ? "rectangle.portrait" : "rectangle") }
    func size(quality: Quality) -> (Int, Int) {
        let sizes: [Aspect: (Int, Int)] = [.square: (2048,2048), .landscape: (2400,1792), .portrait: (1792,2400), .photoLandscape: (2528,1696), .photoPortrait: (1696,2528), .wide: (2752,1536), .story: (1536,2752)]
        let (w,h) = sizes[self]!
        let divisor = quality == .detail ? 1 : (quality == .draft ? 4 : 2)
        return (max(32, (w / divisor / 32) * 32), max(32, (h / divisor / 32) * 32))
    }
}

struct Creation: Codable, Identifiable {
    let id: UUID
    let date: Date
    let prompt: String
    let fileName: String
    let seed: Int
    let aspect: Aspect
    let quality: Quality
    let transparent: Bool
    let steps: Int
    let referenceCount: Int
    var formatPreset: FormatPreset? = nil
}

struct GenerationRequest {
    let prompt: String
    let aspect: Aspect
    let quality: Quality
    let transparent: Bool
    let steps: Int
    let seed: Int
    let references: [URL]
    var formatPreset: FormatPreset? = nil
    var dimensions: (Int, Int) { formatPreset?.renderSize(quality: quality) ?? aspect.size(quality: quality) }
    var effectivePrompt: String {
        transparent ? "This is an RGBA image with transparency. \(prompt). The image has alpha channel and the background is transparent." : prompt
    }
}

enum StudioError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(s) = self { return s }; return nil }
}
