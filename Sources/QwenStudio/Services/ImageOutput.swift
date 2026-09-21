import AppKit
import ImageIO
import UniformTypeIdentifiers

enum ImageOutput {
    static func fittedPNG(_ data: Data, preset: FormatPreset?) throws -> Data {
        guard let preset else { return data }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: preset.size.width, height: preset.size.height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw StudioError.message("Could not prepare the image for this format.")
        }
        let width = CGFloat(preset.size.width), height = CGFloat(preset.size.height)
        let scale = max(width / CGFloat(image.width), height / CGFloat(image.height))
        let drawnWidth = CGFloat(image.width) * scale, drawnHeight = CGFloat(image.height) * scale
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (width-drawnWidth)/2, y: (height-drawnHeight)/2, width: drawnWidth, height: drawnHeight))
        let output = NSMutableData()
        guard let rendered = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw StudioError.message("Could not encode the formatted image.")
        }
        let metadata: CFDictionary? = preset == .document
            ? [kCGImagePropertyDPIWidth: 150, kCGImagePropertyDPIHeight: 150] as CFDictionary : nil
        CGImageDestinationAddImage(destination, rendered, metadata)
        guard CGImageDestinationFinalize(destination) else { throw StudioError.message("Could not save the formatted image.") }
        return output as Data
    }

    @MainActor static func copy(_ data: Data) throws {
        guard let image = NSImage(data: data) else { throw StudioError.message("Could not copy this image.") }
        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        if let tiff = image.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.writeObjects([item]) else { throw StudioError.message("Could not write to the clipboard.") }
    }

    @MainActor static func printImage(_ image: NSImage) {
        let view = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        view.image = image
        view.imageScaling = .scaleProportionallyUpOrDown
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.horizontalPagination = .fit
        info.verticalPagination = .fit
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = true
        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }
}
