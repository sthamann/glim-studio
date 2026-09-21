import SwiftUI

struct GenerationPreviewView: View {
    @ObservedObject var store: StudioStore

    var body: some View {
        ZStack {
            if let image = store.previewImage {
                Image(nsImage: image)
                    .resizable().interpolation(.none).scaledToFit()
                    .padding(18).padding(.bottom, 100)
                    .accessibilityLabel("Live preview of your image")
            }
            VStack(spacing: 16) {
                if store.previewImage != nil {
                    Spacer()
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 46, weight: .light)).foregroundStyle(.indigo).symbolEffect(.pulse)
                    Text("Your idea is taking shape").font(.title2.weight(.medium))
                }
                VStack(spacing: 10) {
                    if store.previewImage != nil {
                        Label("Live preview", systemImage: "sparkles").font(.caption.weight(.semibold))
                    }
                    if store.progress > 0 { ProgressView(value: store.progress).frame(maxWidth: 320) }
                    else { ProgressView().controlSize(.small) }
                    Text(store.phase).font(.subheadline).multilineTextAlignment(.center)
                    if let start = store.startedAt {
                        TimelineView(.periodic(from: start, by: 1)) { context in
                            let seconds = Int(context.date.timeIntervalSince(start))
                            Text("\(seconds / 60):\(String(format: "%02d", seconds % 60)) elapsed")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    Text(store.previewImage == nil
                         ? "The preview appears after the first generation step."
                         : "A rough preview. Final colours and details may differ.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(18).frame(maxWidth: 420)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }.padding(24)
        }
    }
}
