//
//  UpdaterViewModel.swift
//  tnl_ctrl
//
//  Sparkle auto-update integration.
//

import Sparkle

@Observable
final class UpdaterViewModel {
    private let updaterController: SPUStandardUpdaterController
    private(set) var canCheckForUpdates = false
    private var observation: NSKeyValueObservation?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        observation = updaterController.updater.observe(
            \.canCheckForUpdates, options: [.initial, .new]
        ) { [weak self] updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor in
                self?.canCheckForUpdates = value
            }
        }
    }

    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }
}
