import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class StudioStore: ObservableObject {
    @Published var prompt = ""
    @Published var aspect: Aspect = .square
    @Published var formatPreset: FormatPreset?
    @Published var quality: Quality = .standard
    @Published var transparent = false
    @Published var steps = 40
    @Published var fastMode = false
    @Published var references: [URL] = []
    @Published var creations: [Creation] = []
    @Published var selected: UUID?
    @Published var showLibrary = false
    @Published var generating = false
    @Published var importingPhoto = false
    @Published var cancelling = false
    @Published var progress: Double = 0
    @Published var previewImage: NSImage?
    @Published var phase = ""
    @Published var error: String?
    @Published var copiedImageID: UUID?
    @Published var startedAt: Date?
    @Published var fixedSeed = ""
    private var generationTask: Task<Void, Never>?
    private var promptID: String?
    // An isolated library supports recording demos without exposing personal prompts.
    let library = ProcessInfo.processInfo.environment["GLIM_DEMO_LIBRARY"].map { URL(fileURLWithPath: $0) }
        ?? RuntimeManager.support.appendingPathComponent("Bilder")
    var current: Creation? { creations.first { $0.id == selected } }
    var canGenerate: Bool { !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !generating && !importingPhoto }

    init() {
        if ProcessInfo.processInfo.physicalMemory < 32 * 1_073_741_824 { quality = .draft; steps = 20 }
        do {
            try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
            let index = library.appendingPathComponent("library.json")
            if FileManager.default.fileExists(atPath: index.path) {
                creations = try JSONDecoder().decode([Creation].self, from: Data(contentsOf: index))
            }
        } catch { self.error = "Could not read the image library: \(error.localizedDescription)" }
    }
    func url(for creation: Creation) -> URL { library.appendingPathComponent(creation.fileName) }
    func newImage() {
        guard !generating, !importingPhoto else { return }
        selected = nil; showLibrary = false; references = []; prompt = ""
    }
    func useExample(_ text: String, transparent: Bool = false) {
        guard !generating, !importingPhoto else { return }
        prompt = text; self.transparent = transparent; selected = nil; showLibrary = false
    }
    func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]; panel.allowsMultipleSelection = true
        panel.message = "Add up to 10 reference images"
        if panel.runModal() == .OK { importImages(panel.urls) }
    }
    func importImages(_ urls: [URL]) {
        guard !generating else { return }
        guard urls.count + references.count <= 10 else { error = "You can add up to 10 reference images."; return }
        do {
            let directory = RuntimeManager.support.appendingPathComponent("Vorlagen")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var added: [URL] = []
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let image = NSImage(contentsOf: url), let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
                    throw StudioError.message("\(url.lastPathComponent) could not be opened as an image.")
                }
                let dest = directory.appendingPathComponent(UUID().uuidString + ".png")
                try png.write(to: dest, options: .atomic)
                added.append(dest)
            }
            references.append(contentsOf: added)
        } catch { self.error = error.localizedDescription }
    }
    func useAsReference(_ creation: Creation) {
        useAsReferences([creation])
    }
    func useAsReferences(_ items: [Creation]) {
        guard !generating else { return }
        guard !items.isEmpty, items.count <= 10 else { error = "Choose between 1 and 10 reference images."; return }
        references = items.map { url(for: $0) }; prompt = ""; selected = nil; showLibrary = false; formatPreset = nil
    }
    func preparePhotoReference(_ data: Data) throws -> URL {
        guard !generating else { throw StudioError.message("Wait for the current image to finish before adding a photo.") }
        guard references.count < 10 else { throw StudioError.message("You can add up to 10 reference images.") }
        guard let image = NSImage(data: data), let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
            throw StudioError.message("This photo could not be opened as an image.")
        }
        let directory = RuntimeManager.support.appendingPathComponent("Vorlagen")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(UUID().uuidString + ".png")
        try png.write(to: destination, options: .atomic)
        return destination
    }
    func reusePrompt(_ creation: Creation) {
        guard !generating else { return }
        prompt = creation.prompt; aspect = creation.aspect; quality = creation.quality
        transparent = creation.transparent; steps = creation.steps
        fastMode = creation.fastMode ?? false
        references = []; selected = nil; showLibrary = false; formatPreset = creation.formatPreset
    }
    func export(_ creation: Creation) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.title = "Save image as"
        panel.nameFieldStringValue = "Glim-\(creation.date.formatted(.iso8601.year().month().day())).png"
        if panel.runModal() == .OK, let destination = panel.url {
            do { try Data(contentsOf: url(for: creation)).write(to: destination, options: .atomic) }
            catch { self.error = "Could not save: \(error.localizedDescription)" }
        }
    }
    func copyImage(_ creation: Creation) {
        do {
            try ImageOutput.copy(Data(contentsOf: url(for: creation)))
            copiedImageID = creation.id
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copiedImageID == creation.id { copiedImageID = nil }
            }
        } catch { self.error = error.localizedDescription }
    }
    func printImage(_ creation: Creation) {
        guard let image = NSImage(contentsOf: url(for: creation)) else { error = "Could not open this image for printing."; return }
        ImageOutput.printImage(image)
    }
    func generate(using engine: LocalEngine) {
        guard canGenerate else { return }
        let seed: Int
        if fixedSeed.isEmpty { seed = Int.random(in: 0...Int(UInt32.max)) }
        else if let value = Int(fixedSeed), value >= 0, value <= Int(UInt32.max) { seed = value }
        else { error = "Seed must be between 0 and 4,294,967,295, or empty."; return }
        let request = GenerationRequest(prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines), aspect: aspect, quality: quality,
                                        transparent: transparent, steps: steps, seed: seed, references: references,
                                        formatPreset: references.isEmpty ? formatPreset : nil, fastMode: fastMode)
        generating = true; cancelling = false; progress = 0; previewImage = nil; startedAt = Date(); selected = nil; showLibrary = false
        phase = "Loading the model and preparing your prompt …"; promptID = nil
        generationTask = Task {
            let clientID = UUID().uuidString
            let socket = engine.progressSocket(clientID: clientID)
            let progressTask = Task {
                while !Task.isCancelled {
                    do {
                        let event = try await socket.receive()
                        if case let .data(bytes) = event {
                            if !Task.isCancelled, let payload = PreviewFrame.imageData(from: bytes), let image = NSImage(data: payload) {
                                self.previewImage = image
                            }
                            continue
                        }
                        guard case let .string(text) = event, let data = text.data(using: .utf8),
                              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let info = object["data"] as? [String: Any] else { continue }
                        if object["type"] as? String == "progress", let value = info["value"] as? Double, let max = info["max"] as? Double, max > 0 {
                            self.progress = value / max
                            self.phase = "Creating your image · step \(Int(value)) of \(Int(max))"
                        }
                        if object["type"] as? String == "executing", info["node"] as? String == "7" {
                            self.phase = "Finishing the details …"
                        }
                    } catch { break }
                }
            }
            defer {
                progressTask.cancel(); socket.cancel(with: .goingAway, reason: nil)
                generating = false; cancelling = false; previewImage = nil; generationTask = nil; promptID = nil
            }
            do {
                var uploaded: [String] = []
                for ref in request.references {
                    try Task.checkCancellation()
                    uploaded.append(try await engine.upload(ref))
                }
                try Task.checkCancellation()
                promptID = try await engine.submit(request, uploaded: uploaded, clientID: clientID)
                // A cancellation can arrive while submission is in flight; remove that job too.
                if Task.isCancelled { try await engine.cancel(id: promptID); throw CancellationError() }
                let id = promptID!
                while true {
                    try Task.checkCancellation()
                    if let data = try await engine.result(id: id) {
                        guard NSImage(data: data) != nil else { throw StudioError.message("The engine did not return a valid image.") }
                        let creation = Creation(id: UUID(), date: Date(), prompt: request.prompt, fileName: UUID().uuidString + ".png", seed: seed,
                                                aspect: request.aspect, quality: request.quality, transparent: request.transparent, steps: request.steps, referenceCount: request.references.count,
                                                formatPreset: request.formatPreset, fastMode: request.fastMode)
                        try ImageOutput.fittedPNG(data, preset: request.formatPreset).write(to: url(for: creation), options: .atomic)
                        let updated = [creation] + creations
                        try JSONEncoder().encode(updated).write(to: library.appendingPathComponent("library.json"), options: .atomic)
                        creations = updated; selected = creation.id; phase = "Done"; progress = 1
                        await engine.releaseMemoryIfNeeded()
                        break
                    }
                    try await Task.sleep(for: .seconds(1))
                }
            } catch is CancellationError { phase = "Cancelled" }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    func cancel(using engine: LocalEngine) {
        guard generating, !cancelling else { return }
        cancelling = true; phase = "Cancelling …"
        let task = generationTask
        let id = promptID
        Task {
            do { try await engine.cancel(id: id); task?.cancel() }
            catch { self.error = "Could not confirm cancellation: \(error.localizedDescription)"; cancelling = false }
        }
    }
}
