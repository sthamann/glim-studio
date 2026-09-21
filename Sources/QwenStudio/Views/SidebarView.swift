import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: StudioStore
    @ObservedObject var runtime: RuntimeManager
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("YOUR STUDIO") {
                    Button { store.showLibrary = false } label: { Label("Create", systemImage: "sparkles") }
                    Button { store.showLibrary = true } label: { Label("My images", systemImage: "square.grid.2x2") }
                }
                if !store.creations.isEmpty {
                    Section("RECENT IMAGES") {
                        ForEach(store.creations.prefix(12)) { creation in
                            Button {
                                store.selected = creation.id; store.showLibrary = false
                            } label: {
                                Label { Text(creation.prompt).lineLimit(1) } icon: { Image(systemName: creation.referenceCount > 0 ? "photo.on.rectangle" : "photo") }
                            }
                            .disabled(store.generating)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 10) {
                Label("Private. Local. Yours.", systemImage: "lock.shield").font(.caption.weight(.medium))
                Text("Powered by Qwen-Image-2.1").font(.caption2).foregroundStyle(.secondary)
                SettingsLink { Label("Settings", systemImage: "gearshape") }.font(.caption).buttonStyle(.plain)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
        }
    }
}
