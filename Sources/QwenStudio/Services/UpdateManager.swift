import Sparkle
import SwiftUI

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    func check() { controller.checkForUpdates(nil) }
}
