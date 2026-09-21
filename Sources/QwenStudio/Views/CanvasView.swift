import SwiftUI

struct CanvasView: View {
    @ObservedObject var store: StudioStore
    @ObservedObject var runtime: RuntimeManager
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.generating ? "An idea becomes an image." : (store.current == nil ? "Room for your imagination." : "Your image.")).font(.title2.weight(.semibold))
                    Text(store.current == nil ? "Create images. Reimagine ideas." : "Saved to your local library.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let current = store.current, !store.generating {
                    Button { store.copyImage(current) } label: { Label(store.copiedImageID == current.id ? "Copied" : "Copy", systemImage: "doc.on.doc") }.help("Copy image · ⇧⌘C")
                    Button { store.export(current) } label: { Label("Save as …", systemImage: "square.and.arrow.down") }
                    Button { store.printImage(current) } label: { Image(systemName: "printer") }.help("Print … · ⌘P").accessibilityLabel("Print image")
                }
            }.padding(28)
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(.quaternary.opacity(0.18))
                if store.generating {
                    GenerationPreviewView(store: store)
                } else if let creation = store.current {
                    Checkerboard().clipShape(RoundedRectangle(cornerRadius: 20))
                    LocalImageView(url: store.url(for: creation), maxPixelSize: 2_560).padding(18)
                } else {
                    VStack(spacing: 22) {
                        ZStack {
                            Circle().fill(.indigo.opacity(0.08)).frame(width: 126,height: 126)
                            Image(systemName: "photo.badge.plus").font(.system(size: 48, weight: .ultraLight)).foregroundStyle(.indigo)
                        }
                        VStack(spacing: 10) {
                            Text("What if …").font(.system(size: 30, weight: .medium, design: .serif))
                            Text("Describe your idea on the right.\nOr start with a little inspiration.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
                        }
                        VStack(spacing: 10) {
                            idea("A quiet moment", icon: "mountain.2", text: "A small wooden cabin beside a still alpine lake at sunrise, soft mist, warm light, analog photography, beautiful natural colors.")
                            idea("An object in its best light", icon: "cup.and.saucer", text: "A handmade ivory ceramic cup on a warm sandstone pedestal, soft studio light, elegant product photography, subtle shadows, minimal composition.")
                            idea("A sticker with character", icon: "face.smiling", text: "A charming little orange fox reading a book, playful hand-drawn sticker illustration, clean outline.", transparent: true)
                        }.frame(maxWidth: 350)
                    }.padding(30)
                }
            }.padding(.horizontal, 28).padding(.bottom, 18)
            if let current = store.current, !store.generating {
                HStack {
                    Text(current.prompt).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    Button("Use as reference") { store.useAsReference(current) }
                    Button("Reuse prompt") { store.reusePrompt(current) }
                }.padding(.horizontal, 28).padding(.bottom, 20)
            }
            if !runtime.ready { SetupCard(runtime: runtime).padding(.horizontal, 28).padding(.bottom, 22) }
        }
    }
    private func idea(_ title: String, icon: String, text: String, transparent: Bool = false) -> some View {
        Button { store.useExample(text, transparent: transparent) } label: {
            HStack { Image(systemName: icon).frame(width: 22).foregroundStyle(.indigo); Text(title); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(.tertiary) }
                .padding(13).background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
}

struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 16
            for row in 0...Int(size.height / cell) {
                for col in 0...Int(size.width / cell) where (row + col).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(col)*cell, y: CGFloat(row)*cell, width: cell, height: cell)), with: .color(.secondary.opacity(0.045)))
                }
            }
        }.accessibilityHidden(true)
    }
}

struct SetupCard: View {
    @ObservedObject var runtime: RuntimeManager
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "desktopcomputer.and.arrow.down").font(.title2).foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 6) {
                    Text(runtime.busy ? runtime.message : "Set up once. Create locally.").font(.subheadline.weight(.semibold))
                    Text(runtime.failure ?? "Initial setup downloads about \(runtime.precision.downloadGB) GB of model data. Your prompts and images then stay on your Mac.").font(.caption).foregroundStyle(.secondary)
                    if ProcessInfo.processInfo.physicalMemory < 24 * 1_073_741_824 {
                        Text("16 GB is experimental. Draft recommended. Not yet tested on a 16 GB MacBook.").font(.caption).foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                if !runtime.busy {
                    Button(runtime.installed ? "Start engine" : "Set up") { Task { await runtime.prepare() } }.buttonStyle(.borderedProminent)
                }
            }
            if runtime.busy {
                if let p = runtime.progress { ProgressView(value: p) } else { ProgressView().controlSize(.small) }
            }
        }.padding(18).background(.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
