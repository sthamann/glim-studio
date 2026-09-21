import SwiftUI
import PhotosUI

struct PhotoLibraryButton: View {
    @ObservedObject var store: StudioStore
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        let title = store.importingPhoto ? "Importing photo …" : "Photos …"
        HStack(spacing: 8) {
            if store.importingPhoto { ProgressView().controlSize(.small) }
            PhotosPicker(selection: $selection, maxSelectionCount: max(1, 10 - store.references.count), selectionBehavior: .ordered,
                         matching: .images, preferredItemEncoding: .compatible) {
                Label(title, systemImage: "photo.on.rectangle")
            }
            .disabled(store.generating || store.importingPhoto || store.references.count >= 10)
            .help(store.references.count >= 10 ? "Remove a reference before adding another photo." : "Choose up to 10 photos to edit or combine. Selection order is the reference order.")
        }
        .task(id: selection) {
            guard !selection.isEmpty else { return }
            let items = selection
            var imported: [URL] = []
            var committed = false
            store.importingPhoto = true
            defer {
                if !committed { for url in imported { try? FileManager.default.removeItem(at: url) } }
                store.importingPhoto = false
                selection = []
            }
            do {
                for item in items {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw StudioError.message("A selected photo is not available. If it is stored in iCloud, download it in Photos and try again.")
                    }
                    try Task.checkCancellation()
                    imported.append(try store.preparePhotoReference(data))
                }
                try Task.checkCancellation()
                guard imported.count + store.references.count <= 10 else { throw StudioError.message("You can add up to 10 reference images.") }
                store.references.append(contentsOf: imported)
                store.selected = nil
                committed = true
                store.showLibrary = false
            } catch is CancellationError {
                // Leaving the library cancels the import without changing the draft.
            } catch {
                if !Task.isCancelled { store.error = "Could not import photo: \(error.localizedDescription)" }
            }
        }
    }
}
