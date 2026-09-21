import SwiftUI

struct ComposerView: View {
    @ObservedObject var store: StudioStore
    @ObservedObject var runtime: RuntimeManager
    @State private var dropTarget = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Your idea").font(.title3.weight(.semibold))
                Spacer()
                Button { store.newImage() } label: { Image(systemName: "plus") }.help("Start fresh · ⌘N")
            }.padding(22)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.references.isEmpty ? "What would you like to see?" : "What would you like to change?").font(.subheadline.weight(.medium))
                        ZStack(alignment: .topLeading) {
                            if store.prompt.isEmpty { Text(store.references.isEmpty ? "A small lakeside cabin, warm evening light, analog photography …" : "Replace the background with a sunny beach …").foregroundStyle(.tertiary).padding(9).allowsHitTesting(false) }
                            TextEditor(text: $store.prompt).font(.body).scrollContentBackground(.hidden).padding(4).frame(height: 154)
                                .accessibilityLabel("Image description")
                        }
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
                        Text("Describe the subject, style and mood in your preferred language.").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Reference images").font(.subheadline.weight(.medium)); Spacer(); Text("\(store.references.count)/10").font(.caption).foregroundStyle(.secondary) }
                        if !store.references.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                                ForEach(Array(store.references.enumerated()), id: \.element) { index, url in
                                    ZStack(alignment: .topTrailing) {
                                        if let image = NSImage(contentsOf: url) {
                                            Image(nsImage: image).resizable().scaledToFill().frame(width: 78,height: 72).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(alignment: .bottomLeading) { Text("\(index + 1)").font(.caption.bold()).padding(4).background(.regularMaterial, in: Circle()).padding(4) }
                                        }
                                        Button { store.references.remove(at: index) } label: { Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.65)) }.buttonStyle(.plain).padding(3).help("Remove reference")
                                    }
                                }
                            }
                        }
                        Button { store.chooseImages() } label: {
                            VStack(spacing: 7) {
                                Image(systemName: "photo.badge.plus").font(.title2)
                                Text("Drop images here").font(.subheadline)
                                Text("or choose files").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).padding(.vertical, 17)
                            .background(dropTarget ? Color.indigo.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5,4])))
                        }.buttonStyle(.plain)
                        .dropDestination(for: URL.self) { urls, _ in store.importImages(urls); return !urls.isEmpty } isTargeted: { dropTarget = $0 }
                        PhotoLibraryButton(store: store)
                        if store.references.count > 1 {
                            Text("Describe how to combine the images. Refer to them as image 1, image 2, and so on. The first image sets the output shape.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Aspect ratio").font(.subheadline.weight(.medium))
                        if store.references.isEmpty {
                            Picker("Format preset", selection: $store.formatPreset) {
                                Text("Custom aspect ratio").tag(Optional<FormatPreset>.none)
                                ForEach(FormatPreset.allCases) { preset in Text(preset.title).tag(Optional(preset)) }
                            }
                            if let preset = store.formatPreset {
                                Text("\(preset.dimensionsLabel) · saved size").font(.caption.weight(.medium))
                                Text(preset.guidance).font(.caption).foregroundStyle(.secondary)
                                Text("Draft is rendered smaller and resized; use 2K for finer detail.").font(.caption2).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 5) {
                                ForEach(Aspect.allCases) { aspect in
                                    Button { store.aspect = aspect; store.formatPreset = nil } label: {
                                        VStack(spacing: 7) { Image(systemName: aspect.symbol).font(.system(size: 19)); Text(aspect.rawValue).font(.caption2) }
                                            .frame(maxWidth: .infinity).frame(height: 60)
                                            .background(store.formatPreset == nil && store.aspect == aspect ? Color.indigo.opacity(0.13) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                                            .foregroundStyle(store.formatPreset == nil && store.aspect == aspect ? Color.indigo : Color.secondary)
                                    }.buttonStyle(.plain).accessibilityLabel("Format \(aspect.rawValue)").accessibilityAddTraits(store.formatPreset == nil && store.aspect == aspect ? .isSelected : [])
                                }
                            }
                        } else { Label("Matches your first reference", systemImage: "aspectratio").font(.caption).foregroundStyle(.secondary) }
                        Picker("Resolution", selection: $store.quality) { ForEach(Quality.allCases) { q in Text(q.title).tag(q) } }.pickerStyle(.segmented)
                            .onChange(of: store.quality) { _, value in store.steps = value == .draft ? 20 : 40 }
                        Text(store.quality.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle(isOn: $store.transparent) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transparent background").font(.subheadline)
                            Text("For stickers, cutouts and isolated subjects").font(.caption).foregroundStyle(.secondary)
                        }
                    }.toggleStyle(.switch).controlSize(.small)
                    DisclosureGroup("Advanced") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Fast mode · experimental", isOn: $store.fastMode)
                            Text("Reuses intermediate results to save time. Fine details, faces and lettering can change. Turn off for your final image.")
                                .font(.caption).foregroundStyle(.secondary)
                            Stepper("Steps: \(store.steps)", value: $store.steps, in: 10...60, step: 5)
                            TextField("Seed (leave empty for a new variation)", text: $store.fixedSeed).textFieldStyle(.roundedBorder)
                            Text("40 steps is the official recommendation. Use a fixed seed to compare variations.").font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 10)
                    }.font(.caption)
                }.padding(.horizontal, 22).padding(.bottom, 22)
            }.disabled(store.generating)
            Divider()
            VStack(spacing: 9) {
                if store.generating {
                    Button { store.cancel(using: runtime.engine) } label: { Label(store.cancelling ? "Cancelling …" : "Cancel", systemImage: "stop.fill").frame(maxWidth: .infinity).padding(.vertical, 8) }
                        .disabled(store.cancelling)
                } else {
                    Button { store.generate(using: runtime.engine) } label: { Label(store.references.isEmpty ? "Create image" : "Edit image", systemImage: "sparkles").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 8) }
                        .buttonStyle(.borderedProminent).disabled(!runtime.ready || !store.canGenerate)
                }
                Text(runtime.ready ? (store.fastMode ? "Experimental Fast mode · ⌘↩" : "Locally on your Mac · ⌘↩") : "Ready after setup").font(.caption2).foregroundStyle(.secondary)
            }.padding(20)
        }
    }
}
