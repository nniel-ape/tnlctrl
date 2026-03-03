//
//  ServiceStore.swift
//  tnl_ctrl
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "nniel.tnlctrl", category: "ServiceStore")

@MainActor
final class ServiceStore {
    static let shared = ServiceStore()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private init() {
        migrateFromTunnelMasterIfNeeded()
    }

    // MARK: - Migration

    /// One-time migration from old ~/Library/Application Support/TunnelMaster/ to tnl_ctrl/
    private func migrateFromTunnelMasterIfNeeded() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        else { return }

        let oldDir = appSupport.appendingPathComponent("TunnelMaster", isDirectory: true)
        let newDir = appSupport.appendingPathComponent("tnl_ctrl", isDirectory: true)

        guard fm.fileExists(atPath: oldDir.path),
              !fm.fileExists(atPath: newDir.path)
        else { return }

        do {
            try fm.moveItem(at: oldDir, to: newDir)
            logger.info("Migrated data from TunnelMaster/ to tnl_ctrl/")
        } catch {
            logger.error("Failed to migrate data directory: \(error.localizedDescription)")
        }
    }

    // MARK: - File Paths

    private var applicationSupportURL: URL {
        get throws {
            let url = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return url.appendingPathComponent("tnl_ctrl", isDirectory: true)
        }
    }

    private var servicesURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("services.json")
        }
    }

    private var tunnelConfigURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("tunnel-config.json")
        }
    }

    private var settingsURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("settings.json")
        }
    }

    private var serversURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("servers.json")
        }
    }

    private var presetsURL: URL {
        get throws {
            try applicationSupportURL.appendingPathComponent("presets.json")
        }
    }

    // MARK: - Services

    func loadServices() async throws -> [Service] {
        let url = try servicesURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([Service].self, from: data)
    }

    func saveServices(_ services: [Service]) async throws {
        let url = try servicesURL

        // Ensure directory exists
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(services)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Tunnel Config

    func loadTunnelConfig() async throws -> TunnelConfig {
        let url = try tunnelConfigURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .default
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(TunnelConfig.self, from: data)
    }

    func saveTunnelConfig(_ config: TunnelConfig) async throws {
        let url = try tunnelConfigURL

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - App Settings

    func loadSettings() async throws -> AppSettings {
        let url = try settingsURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .default
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(AppSettings.self, from: data)
    }

    func saveSettings(_ settings: AppSettings) async throws {
        let url = try settingsURL

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Servers

    func loadServers() async throws -> [Server] {
        let url = try serversURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([Server].self, from: data)
    }

    func saveServers(_ servers: [Server]) async throws {
        let url = try serversURL

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(servers)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Presets

    func loadPresets() async throws -> [TunnelPreset] {
        let url = try presetsURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([TunnelPreset].self, from: data)
    }

    func savePresets(_ presets: [TunnelPreset]) async throws {
        let url = try presetsURL

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(presets)
        try data.write(to: url, options: .atomic)
    }
}
