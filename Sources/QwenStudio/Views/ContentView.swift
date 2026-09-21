import SwiftUI

struct ContentView: View {
    @ObservedObject var store: StudioStore
    @ObservedObject var runtime: RuntimeManager
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, runtime: runtime)
                .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 240)
        } detail: {
            HStack(spacing: 0) {
                Group {
                    if store.showLibrary { LibraryView(store: store) }
                    else { CanvasView(store: store, runtime: runtime) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                ComposerView(store: store, runtime: runtime).frame(width: 320)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack.fill").foregroundStyle(.indigo)
                    Text("Glim Studio").font(.headline)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 6) {
                    Circle().fill(runtime.ready ? Color.green : Color.orange).frame(width: 7,height: 7)
                    Text(runtime.ready ? "On your Mac" : "Setup").font(.caption)
                }.help("Your images and prompts stay on this Mac")
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Okay", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}
