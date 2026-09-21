import SwiftUI

struct SettingsView: View {
    @ObservedObject var runtime: RuntimeManager
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("Glim Studio", systemImage: "sparkles.rectangle.stack.fill").font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text("Your local image studio").font(.headline)
                Text("Powered by Qwen-Image-2.1 through a private local ComfyUI engine. No cloud account or API key needed. Only initial setup requires internet.").foregroundStyle(.secondary)
            }
            LabeledContent("Memory", value: "\(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) GB")
            LabeledContent("Engine", value: runtime.ready ? "Ready locally" : runtime.message)
            LabeledContent("Model variant", value: runtime.precision.title)
            Text("Below 48 GB, the app uses the compact model. Below 32 GB, it starts with small drafts. MacBook performance has not yet been measured.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Open image library") { NSWorkspace.shared.open(RuntimeManager.support.appendingPathComponent("Bilder")) }
                Button("Open logs") { NSWorkspace.shared.open(runtime.root) }
            }
            Button("Check for Updates…") { UpdateManager.shared.check() }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Model license").font(.headline)
                Text("Qwen-Image-2.1 is licensed for research and evaluation. Commercial use requires a separate license from the rights holder.").font(.caption).foregroundStyle(.secondary)
                Link("Read Qwen Research License", destination: URL(string: "https://github.com/QwenLM/Qwen-Image-2.1/blob/main/LICENSE")!)
            }
            Text("Glim Studio 0.1 · Apple Silicon · macOS 14+").font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
