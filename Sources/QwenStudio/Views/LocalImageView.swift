import SwiftUI

/// A stable display image, reloaded only when its URL or requested size changes.
/// Typing and progress updates must never decode a file in a view's body.
struct LocalImageView: View {
    let url: URL
    let maxPixelSize: Int
    var contentMode: ContentMode = .fit
    @State private var image: CGImage?
    @State private var failed = false

    private struct Request: Hashable {
        let url: URL
        let size: Int
    }

    var body: some View {
        let request = Request(url: url, size: maxPixelSize)
        ZStack {
            if let image {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Color.clear.overlay {
                    if failed { Image(systemName: "photo").foregroundStyle(.secondary) }
                    else { ProgressView().controlSize(.small) }
                }
            }
        }
        .task(id: request) {
            image = nil
            failed = false
            do {
                let loaded = try await DisplayImageCache.shared.image(at: request.url, maxPixelSize: request.size)
                try Task.checkCancellation()
                image = loaded
            } catch is CancellationError {
                // A changed selection owns the next load; do not display an old result.
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
    }
}
