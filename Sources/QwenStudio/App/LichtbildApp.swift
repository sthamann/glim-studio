import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { RuntimeManager.shared.stop() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct LichtbildApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = StudioStore()
    @StateObject private var runtime = RuntimeManager.shared
    @StateObject private var updates = UpdateManager.shared
    var body: some Scene {
        Window("Glim Studio", id: "studio") {
            ContentView(store: store, runtime: runtime)
                .frame(minWidth: 1040, minHeight: 700)
                .tint(.indigo)
                .task { await runtime.prepare() }
        }
        .defaultSize(width: 1320, height: 870)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updates.check() }.disabled(store.generating)
            }
            CommandGroup(replacing: .newItem) {
                Button("New image") { store.newImage() }.keyboardShortcut("n").disabled(store.generating)
                Button("Add reference images …") { store.chooseImages() }.keyboardShortcut("o").disabled(store.generating)
            }
            CommandGroup(after: .saveItem) {
                Button("Save image as …") { if let c = store.current { store.export(c) } }
                    .keyboardShortcut("s").disabled(store.current == nil)
            }
            CommandGroup(replacing: .printItem) {
                Button("Print image …") { if let c = store.current { store.printImage(c) } }
                    .keyboardShortcut("p").disabled(store.current == nil)
            }
            CommandMenu("Image") {
                Button("Copy image") { if let c = store.current { store.copyImage(c) } }
                    .keyboardShortcut("c", modifiers: [.command, .shift]).disabled(store.current == nil)
                Button("Use as reference") { if let c = store.current { store.useAsReference(c) } }
                    .disabled(store.current == nil || store.generating)
                Divider()
                Button("Create image") { store.generate(using: runtime.engine) }.keyboardShortcut(.return, modifiers: .command)
                    .disabled(!runtime.ready || !store.canGenerate)
                Button("Cancel") { store.cancel(using: runtime.engine) }.keyboardShortcut(".").disabled(!store.generating)
            }
        }
        Settings { SettingsView(runtime: runtime).frame(width: 520).padding(28) }
    }
}
