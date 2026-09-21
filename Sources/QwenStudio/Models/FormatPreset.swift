import Foundation

enum FormatPreset: String, CaseIterable, Codable, Identifiable {
    case xHeader, xArticle, xProfile, linkedInHeader, linkedInArticle, linkedInProfile, linkedInCompany, linkedInPost
    case socialSquare, socialPortrait, story, presentation, websiteHero, product, document
    var id: String { rawValue }
    var title: String {
        switch self {
        case .xHeader: "X · Profile header"
        case .xArticle: "X · Article cover"
        case .xProfile: "X · Profile picture"
        case .linkedInHeader: "LinkedIn · Profile banner"
        case .linkedInArticle: "LinkedIn · Article / newsletter"
        case .linkedInProfile: "LinkedIn · Profile picture"
        case .linkedInCompany: "LinkedIn · Company cover"
        case .linkedInPost: "LinkedIn · Link post"
        case .socialSquare: "Social · Square post"
        case .socialPortrait: "Social · Portrait post"
        case .story: "Social · Story / reel cover"
        case .presentation: "Business · Presentation slide"
        case .websiteHero: "Business · Website hero"
        case .product: "Business · Product image"
        case .document: "Business · A4 document cover"
        }
    }
    var size: (width: Int, height: Int) {
        switch self {
        case .xHeader: (1500, 500)
        case .xArticle: (2500, 1000)
        case .xProfile, .linkedInProfile: (400, 400)
        case .linkedInHeader: (1584, 396)
        case .linkedInArticle, .presentation: (1920, 1080)
        case .linkedInCompany: (1512, 256)
        case .linkedInPost: (1200, 627)
        case .socialSquare: (1080, 1080)
        case .socialPortrait: (1080, 1350)
        case .story: (1080, 1920)
        case .websiteHero: (1920, 640)
        case .product: (2048, 2048)
        case .document: (1240, 1754)
        }
    }
    var dimensionsLabel: String { "\(size.width) × \(size.height) px" }
    var guidance: String {
        switch self {
        case .xArticle: "Suggested 5:2 layout. Check the crop in X's article editor."
        case .xHeader, .linkedInHeader, .linkedInCompany: "Keep important details near the center; profile photos and mobile crops may cover the edges."
        case .xProfile, .linkedInProfile: "Keep the subject centered for the circular profile crop."
        case .document: "A4 proportions at 150 pixels per inch. Use 2K for more detail."
        default: "Resolution controls generated detail. The saved image is resized and lightly center-cropped to this format."
        }
    }
    func renderSize(quality: Quality) -> (Int, Int) {
        let ratio = Double(size.width) / Double(size.height)
        let edge = Double(quality.referenceSize)
        let width = edge * sqrt(ratio), height = edge / sqrt(ratio)
        let scale = min(1, 4096 / max(width, height))
        return (max(192, Int((width * scale / 32).rounded()) * 32),
                max(192, Int((height * scale / 32).rounded()) * 32))
    }
}
