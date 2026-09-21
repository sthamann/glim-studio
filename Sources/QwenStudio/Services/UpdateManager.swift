import Sparkle
import SwiftUI

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    private let controller: SPUStandardUpdaterController
    private var startupError: Error?
    init() {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        do { try controller.updater.start() }
        catch { startupError = error }
    }
    func check() {
        if let startupError { NSAlert(error: startupError).runModal() }
        else { controller.checkForUpdates(nil) }
    }
}
