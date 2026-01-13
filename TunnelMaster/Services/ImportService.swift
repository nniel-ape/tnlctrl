//
//  ImportService.swift
//  TunnelMaster
//

import Foundation

actor ImportService {
    static let shared = ImportService()

    private let parsers: [ConfigImporter]

    private init() {
        let keychain = KeychainManager.shared
        parsers = [
            SingBoxParser(keychainManager: keychain),
            ClashParser(keychainManager: keychain),
            V2RayParser(keychainManager: keychain),
            URIParser(keychainManager: keychain)
        ]
    }

    func importConfig(text: String) async throws -> [Service] {
        // Try each parser
        for parser in parsers {
            if parser.canImport(text: text) {
                return try await parser.parse(text: text)
            }
        }

        throw ImportError.unsupportedFormat
    }

    func importConfig(data: Data) async throws -> [Service] {
        // First try as text
        if let text = String(data: data, encoding: .utf8) {
            for parser in parsers {
                if parser.canImport(text: text) {
                    return try await parser.parse(text: text)
                }
            }
        }

        // Then try as binary data
        for parser in parsers {
            if parser.canImport(data: data) {
                return try await parser.parse(data: data)
            }
        }

        throw ImportError.unsupportedFormat
    }

    func importConfig(from url: URL) async throws -> [Service] {
        let data = try Data(contentsOf: url)
        return try await importConfig(data: data)
    }
}

enum ImportError: LocalizedError {
    case unsupportedFormat
    case noServicesFound
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "Unsupported config format. Supported formats: sing-box, Clash, V2Ray, and proxy URIs."
        case .noServicesFound:
            "No proxy services found in the config."
        case .networkError(let detail):
            "Network error: \(detail)"
        }
    }
}
