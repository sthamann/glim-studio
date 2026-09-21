import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: StudioStore
    @State private var search = ""
    @State private var selecting = false
    @State private var selection: [UUID] = []
    var filtered: [Creation] { search.isEmpty ? store.creations : store.creations.filter { $0.prompt.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("My images").font(.title2.weight(.semibold))
                Spacer()
                Text("\(store.creations.count) images").foregroundStyle(.secondary)
                Button(selecting ? "Cancel selection" : "Select") { selecting.toggle(); selection = [] }
                    .disabled(store.creations.isEmpty || store.generating)
                if selecting {
                    Button("Use \(selection.count) images") {
                        store.useAsReferences(selection.compactMap { id in store.creations.first { $0.id == id } })
                    }.disabled(selection.isEmpty).buttonStyle(.borderedProminent)
                }
                PhotoLibraryButton(store: store)
            }
            Text("Browse your creations, or choose up to 10 photos to edit or combine from your Apple Photos library.")
                .font(.subheadline).foregroundStyle(.secondary)
            TextField("Search prompts", text: $search).textFieldStyle(.roundedBorder)
            if filtered.isEmpty {
                ContentUnavailableView(store.creations.isEmpty ? "Your first image is waiting" : "No matching images", systemImage: "photo.on.rectangle.angled", description: Text("Your locally created images will appear here."))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: 20) {
                        ForEach(filtered) { creation in
                            Button {
                                if selecting {
                                    if let index = selection.firstIndex(of: creation.id) { selection.remove(at: index) }
                                    else if selection.count < 10 { selection.append(creation.id) }
                                    else { store.error = "You can combine up to 10 images." }
                                } else { store.selected = creation.id; store.showLibrary = false }
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    if let image = NSImage(contentsOf: store.url(for: creation)) {
                                        Image(nsImage: image).resizable().scaledToFit().frame(height: 175).frame(maxWidth: .infinity)
                                            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    Text(creation.prompt).lineLimit(2).font(.subheadline)
                                    Text(creation.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                }.overlay(alignment: .topTrailing) {
                                    if selecting {
                                        if let index = selection.firstIndex(of: creation.id) {
                                            Text("\(index + 1)").font(.headline).padding(8).background(.indigo, in: Circle()).foregroundStyle(.white).padding(6)
                                        } else { Image(systemName: "circle").font(.title2).padding(6).background(.regularMaterial, in: Circle()) }
                                    }
                                }
                            }.buttonStyle(.plain)
                            .contextMenu {
                                Button("Copy image") { store.copyImage(creation) }
                                Button("Save as …") { store.export(creation) }
                                Button("Use as reference") { store.useAsReference(creation) }
                                Button("Print …") { store.printImage(creation) }
                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.url(for: creation)]) }
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }.padding(28)
    }
}
