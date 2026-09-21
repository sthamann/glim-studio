import Foundation

@MainActor
final class RuntimeManager: ObservableObject {
    static let shared = RuntimeManager()
    static let support: URL = {
        let legacy = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Lichtbild Studio")
        if FileManager.default.fileExists(atPath: legacy.path) { return legacy }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Glim Studio")
    }()
    let root = support.appendingPathComponent("runtime")
    @Published var ready = false
    @Published var busy = false
    @Published var message = "Preparing the local engine"
    @Published var progress: Double?
    @Published var failure: String?
    private var server: Process?
    private var installer: Process?
    private var logHandle: FileHandle?
    private(set) var port = Int.random(in: 18200...19200)
    let precision: ModelPrecision = ProcessInfo.processInfo.physicalMemory < 48 * 1_073_741_824 ? .compact : .full
    var engine: LocalEngine { LocalEngine(baseURL: URL(string: "http://127.0.0.1:\(port)")!, precision: precision) }
    var installed: Bool {
        let files = ["ready.json", "venv/bin/python", "ComfyUI/main.py",
                     "ComfyUI/models/diffusion_models/qwen_image_2.1_\(precision.rawValue).verified",
                     "ComfyUI/models/text_encoders/qwen3vl_8b_\(precision.rawValue).verified",
                     "ComfyUI/models/vae/qwen_image_2.1_vae_bf16.verified"]
        return files.allSatisfy { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    func prepare() async {
        guard !busy, !ready else { return }
        busy = true; failure = nil
        defer { busy = false }
        do {
            guard ProcessInfo.processInfo.physicalMemory >= 16 * 1_073_741_824 else {
                throw StudioError.message("This Mac has insufficient memory for this model. 24 GB or more is recommended; 16 GB is experimental.")
            }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if !installed {
                let available = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
                let required: Int64 = precision == .full ? 45_000_000_000 : 28_000_000_000
                if let available, available < required {
                    throw StudioError.message("Please free at least \(required / 1_000_000_000) GB of disk space for the model and its runtime, then try setup again.")
                }
                try await install()
            }
            try await start()
        } catch {
            failure = error.localizedDescription
            message = "Setup needs attention"
            ready = false
        }
    }

    private func run(_ executable: URL, _ arguments: [String], capture: Bool = false) async throws {
        let process = Process()
        process.executableURL = executable; process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        let errURL = root.appendingPathComponent("setup.log")
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        let err = try FileHandle(forWritingTo: errURL)
        process.standardError = err
        installer = process
        let reader = Task.detached { [self] in
            for try await line in pipe.fileHandleForReading.bytes.lines {
                guard capture, let data = line.data(using: .utf8), let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let message = event["message"] as? String else { continue }
                let p = event["progress"] as? Double
                await MainActor.run { self.message = message; self.progress = p }
            }
        }
        defer { reader.cancel(); try? err.close(); installer = nil }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 { continuation.resume() }
                else { continuation.resume(throwing: StudioError.message("Setup could not finish. The download can be resumed. See the setup log for details.")) }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    private func install() async throws {
        guard let resources = Bundle.main.resourceURL else { throw StudioError.message("App resources are missing.") }
        let uv = resources.appendingPathComponent("uv")
        let python = root.appendingPathComponent("venv/bin/python")
        if !FileManager.default.fileExists(atPath: python.path) {
            message = "Setting up Python …"
            try await run(uv, ["venv", "--python", "3.12", root.appendingPathComponent("venv").path])
        }
        var arguments = [resources.appendingPathComponent("backend/setup.py").path, root.path, uv.path]
        if precision == .compact { arguments.append("--compact") }
        try await run(python, arguments, capture: true)
    }

    private func start() async throws {
        message = "Starting the image engine on your Mac …"; progress = nil
        let process = Process()
        process.executableURL = root.appendingPathComponent("venv/bin/python")
        process.currentDirectoryURL = root.appendingPathComponent("ComfyUI")
        guard let launcher = Bundle.main.resourceURL?.appendingPathComponent("backend/engine.py") else { throw StudioError.message("Engine resources are missing.") }
        process.arguments = ["-u", launcher.path, root.path, "--listen", "127.0.0.1", "--port", String(port), "--disable-auto-launch", "--disable-api-nodes", "--disable-all-custom-nodes", "--use-pytorch-cross-attention", "--preview-method", "latent2rgb"]
        var env = ProcessInfo.processInfo.environment
        env["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        env["HF_HUB_OFFLINE"] = "1"
        env["TRANSFORMERS_OFFLINE"] = "1"
        env["LICHTBILD_PARENT_PID"] = String(ProcessInfo.processInfo.processIdentifier)
        process.environment = env
        let log = root.appendingPathComponent("engine.log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        logHandle = try FileHandle(forWritingTo: log)
        process.standardOutput = logHandle; process.standardError = logHandle
        server = process
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.server === process else { return }
                self.ready = false
                if !self.busy { self.failure = "The local engine stopped. Please start it again." }
            }
        }
        try process.run()
        for _ in 0..<120 {
            guard process.isRunning else { throw StudioError.message("The image engine could not start. See the engine log for details.") }
            if (try? await engine.health()) != nil {
                ready = true; message = "Ready locally"; return
            }
            try await Task.sleep(for: .seconds(1))
        }
        process.terminate()
        throw StudioError.message("Startup timed out. Please try again.")
    }

    func stop() {
        let owned = server
        server = nil
        if owned?.isRunning == true { owned?.terminate() }
        if installer?.isRunning == true { installer?.terminate() }
        ready = false
        try? logHandle?.close()
    }
}
