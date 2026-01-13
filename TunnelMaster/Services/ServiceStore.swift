//
//  ServiceStore.swift
//  TunnelMaster
//

import Foundation

actor ServiceStore {
    static let shared = ServiceStore()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - File Paths

    private var applicationSupportURL: URL {
        get throws {
            let url = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return url.appendingPathComponent("TunnelMaster", isDirectory: true)
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
}
