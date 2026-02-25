import Foundation
import Sparkle

/// Thin wrapper around Sparkle's SPUUpdater, exposed as an ObservableObject so
/// existing SwiftUI bindings (isChecking) continue to compile without changes.
@MainActor
class UpdateManager: ObservableObject {
    /// Whether a manual check is in flight (used by the UI spinner).
    @Published var isChecking = false

    // Sparkle's standard controller owns the updater and all UI.
    // It must be kept alive for the app's lifetime.
    let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Trigger a user-visible update check (shows Sparkle UI).
    func checkForUpdates(forced: Bool = false) {
        isChecking = true
        updaterController.checkForUpdates(nil)
        // Reset spinner after a short delay so it doesn't spin forever
        // while Sparkle shows its own UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isChecking = false
        }
    }

    /// Expose the underlying SPUUpdater for bindings in SwiftUI (e.g. menu extras).
    var updater: SPUUpdater {
        updaterController.updater
    }
}

/// Observes Sparkle's `canCheckForUpdates` property so SwiftUI buttons can
/// disable themselves while an update session is already in progress.
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    var updater: SPUUpdater? {
        didSet {
            observation = updater?.publisher(for: \.canCheckForUpdates)
                .assign(to: \.canCheckForUpdates, on: self)
        }
    }

    private var observation: Any?
}
