import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: StudioStore
    @State private var search = ""
    var filtered: [Creation] { search.isEmpty ? store.creations : store.creations.filter { $0.prompt.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("My images").font(.title2.weight(.semibold)); Spacer(); Text("\(store.creations.count) images").foregroundStyle(.secondary) }
            TextField("Search prompts", text: $search).textFieldStyle(.roundedBorder)
            if filtered.isEmpty {
                ContentUnavailableView(store.creations.isEmpty ? "Your first image is waiting" : "No matching images", systemImage: "photo.on.rectangle.angled", description: Text("Your locally created images will appear here."))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190))], spacing: 20) {
                        ForEach(filtered) { creation in
                            Button { store.selected = creation.id; store.showLibrary = false } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    if let image = NSImage(contentsOf: store.url(for: creation)) {
                                        Image(nsImage: image).resizable().scaledToFit().frame(height: 175).frame(maxWidth: .infinity)
                                            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    Text(creation.prompt).lineLimit(2).font(.subheadline)
                                    Text(creation.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                            .contextMenu {
                                Button("Export …") { store.export(creation) }
                                Button("Use as reference") { store.useAsReference(creation) }
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
