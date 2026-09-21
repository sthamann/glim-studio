import Foundation

/// ComfyUI's legacy binary preview: big-endian event, image format, image bytes.
enum PreviewFrame {
    static func imageData(from data: Data) -> Data? {
        guard data.count > 8, data.count < 8_000_000 else { return nil }
        let header = Array(data.prefix(8))
        guard header.prefix(4).elementsEqual([0, 0, 0, 1]),
              header[4...6].allSatisfy({ $0 == 0 }), [1, 2].contains(header[7]) else { return nil }
        return Data(data.dropFirst(8))
    }
}
