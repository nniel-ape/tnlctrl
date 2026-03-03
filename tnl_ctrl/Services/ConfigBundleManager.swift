//
//  ConfigBundleManager.swift
//  tnl_ctrl
//
//  Orchestrates export and import of the full app configuration.
//

import AppKit
import Foundation
import OSLog
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "nniel.tnlctrl", category: "ConfigBundleManager")

@MainActor
final class ConfigBundleManager {
    private let appState: AppState
    private let keychain: any KeychainManaging

    init(appState: AppState, keychain: any KeychainManaging = KeychainManager.shared) {
        self.appState = appState
        self.keychain = keychain
    }

    // MARK: - Export

    func exportConfig() async throws {
        let bundle = try await buildBundle()
        let data = try encodeBundle(bundle)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.tnlctrlConfig]
        panel.nameFieldStringValue = "tnl_ctrl-Backup"
        panel.message = "Credentials are stored in plaintext in this file. Keep it safe."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        try data.write(to: url, options: .atomic)
        logger.info("Exported config to \(url.path, privacy: .public)")
    }

    // MARK: - Import

    func readBundleFromFile() throws -> ConfigBundle? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.tnlctrlConfig]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let bundle = try decoder.decode(ConfigBundle.self, from: data)

        guard bundle.version <= ConfigBundle.currentVersion else {
            throw ConfigBundleError.unsupportedVersion(bundle.version)
        }

        return bundle
    }

    func applyBundle(_ bundle: ConfigBundle) async throws {
        // Disconnect tunnel if connected
        if appState.isConnected {
            await appState.disconnect()
        }

        // Clear existing Keychain entries
        try await keychain.deleteAll()

        // Write new credentials
        for (ref, value) in bundle.credentials {
            try await keychain.save(value, for: ref)
        }

        // Save all data files via ServiceStore
        let store = ServiceStore.shared
        try await store.saveServices(bundle.services)
        try await store.saveServers(bundle.servers)
        try await store.saveTunnelConfig(bundle.tunnelConfig)
        try await store.saveSettings(bundle.settings)
        try await store.savePresets(bundle.presets)

        // Update in-memory state directly
        appState.services = bundle.services
        appState.servers = bundle.servers
        appState.tunnelConfig = bundle.tunnelConfig
        appState.settings = bundle.settings
        appState.presets = bundle.presets

        logger.info("Imported config: \(bundle.services.count) services, \(bundle.servers.count) servers")
    }

    // MARK: - Private

    private func buildBundle() async throws -> ConfigBundle {
        var credentials: [String: String] = [:]
        for service in appState.services {
            guard let ref = service.credentialRef else { continue }
            if let value = try await keychain.get(ref) {
                credentials[ref] = value
            }
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        return ConfigBundle(
            version: ConfigBundle.currentVersion,
            exportedAt: Date(),
            appVersion: appVersion,
            services: appState.services,
            servers: appState.servers,
            tunnelConfig: appState.tunnelConfig,
            settings: appState.settings,
            presets: appState.presets,
            credentials: credentials
        )
    }

    private func encodeBundle(_ bundle: ConfigBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }
}

// MARK: - Errors

enum ConfigBundleError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "This file was created with a newer version of tnl_ctrl (format v\(version)). Please update the app."
        }
    }
}
