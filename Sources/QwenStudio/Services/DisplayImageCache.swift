import Foundation
import ImageIO

/// Display copies only. Library and imported reference files have immutable UUID names;
/// generation, export and printing continue to use the original files.
actor DisplayImageCache {
    static let shared = DisplayImageCache()
    private let images = NSCache<NSString, CGImage>()

    init() {
        images.totalCostLimit = 64 * 1_024 * 1_024
        images.countLimit = 80
    }

    func image(at url: URL, maxPixelSize: Int) throws -> CGImage {
        try Task.checkCancellation()
        let size = max(1, min(maxPixelSize, 2_560))
        let key = "\(size):\(url.absoluteString)" as NSString
        if let image = images.object(forKey: key) { return image }
        // This actor serializes decoding away from the main actor. Disable source
        // caching so a 78-point reference never retains a full-resolution bitmap.
        guard let source = CGImageSourceCreateWithURL(url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: size,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        try Task.checkCancellation()
        images.setObject(image, forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}
