import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

@main
struct DisplayImageChecks {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("large.png")
        // A camera-sized, opaque/transparent fixture with deterministic texture.
        let width = 4_032, height = 3_024
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        var seed: UInt32 = 42
        for i in stride(from: 0, to: bytes.count, by: 4) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            bytes[i] = UInt8(truncatingIfNeeded: seed >> 24)
            bytes[i + 1] = UInt8(truncatingIfNeeded: seed >> 16)
            bytes[i + 2] = UInt8(truncatingIfNeeded: seed >> 8)
            bytes[i + 3] = i < bytes.count / 2 ? 0 : 255
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let original = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, original, nil)
        precondition(CGImageDestinationFinalize(destination))
        let originalData = try Data(contentsOf: url)
        let clock = ContinuousClock()
        var legacy: [Double] = []
        for _ in 0..<5 {
            let start = clock.now
            autoreleasepool {
                let image = NSImage(contentsOf: url)!
                let target = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 192,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: target)
                image.draw(in: NSRect(x: 0, y: 0, width: 256, height: 192))
                NSGraphicsContext.restoreGraphicsState()
            }
            legacy.append(seconds(start.duration(to: clock.now)))
        }
        let cache = DisplayImageCache()
        var ticks = 0
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled {
                ticks += 1
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
        let coldStart = clock.now
        let thumbnail = try await cache.image(at: url, maxPixelSize: 256)
        let cold = seconds(coldStart.duration(to: clock.now))
        heartbeat.cancel()
        precondition(ticks > 1, "Decoding must let the main actor keep processing events")
        precondition(thumbnail.width == 256 && thumbnail.height == 192)
        precondition(thumbnail.alphaInfo != .none && thumbnail.alphaInfo != .noneSkipLast)
        let warmStart = clock.now
        for _ in 0..<100 {
            let reused = try await cache.image(at: url, maxPixelSize: 256)
            precondition(reused === thumbnail, "Typing must reuse the decoded bitmap")
        }
        let warm = seconds(warmStart.duration(to: clock.now)) / 100
        let larger = try await cache.image(at: url, maxPixelSize: 640)
        precondition(larger.width == 640 && larger.height == 480)
        precondition(larger !== thumbnail)
        // Check EXIF orientation is respected when creating thumbnails.
        let rotatedURL = directory.appendingPathComponent("rotated.jpg")
        let rotated = CGImageDestinationCreateWithURL(rotatedURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(rotated, original, [kCGImagePropertyOrientation: 6] as CFDictionary)
        precondition(CGImageDestinationFinalize(rotated))
        let oriented = try await cache.image(at: rotatedURL, maxPixelSize: 256)
        precondition(oriented.width == 192 && oriented.height == 256)
        do {
            _ = try await cache.image(at: directory.appendingPathComponent("missing.png"), maxPixelSize: 256)
            preconditionFailure("Missing files must report an error")
        } catch is CocoaError { }
        let afterData = try Data(contentsOf: url)
        precondition(afterData == originalData, "Display loading must never alter originals")
        let report: [String: Any] = ["fixture_pixels": [width, height], "legacy_decode_seconds": legacy,
            "cold_thumbnail_seconds": cold, "warm_cache_mean_seconds": warm,
            "main_actor_heartbeats_during_cold_decode": ticks,
            "thumbnail_bitmap_bytes": thumbnail.bytesPerRow * thumbnail.height,
            "originals_unchanged": true, "orientation_checked": true, "cache_identity_checked": true]
        print(String(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
