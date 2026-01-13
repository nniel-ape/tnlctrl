//
//  ConfigImporter.swift
//  TunnelMaster
//

import Foundation

protocol ConfigImporter {
    /// Check if this importer can handle the given data
    func canImport(data: Data) -> Bool

    /// Check if this importer can handle the given text
    func canImport(text: String) -> Bool

    /// Parse data into services
    func parse(data: Data) async throws -> [Service]

    /// Parse text into services
    func parse(text: String) async throws -> [Service]
}

extension ConfigImporter {
    func canImport(text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return canImport(data: data)
    }

    func parse(text: String) async throws -> [Service] {
        guard let data = text.data(using: .utf8) else {
            throw ConfigImportError.invalidEncoding
        }
        return try await parse(data: data)
    }
}

enum ConfigImportError: LocalizedError {
    case invalidEncoding
    case invalidFormat(String)
    case unsupportedProtocol(String)
    case missingRequiredField(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            "Invalid text encoding"
        case .invalidFormat(let detail):
            "Invalid format: \(detail)"
        case .unsupportedProtocol(let proto):
            "Unsupported protocol: \(proto)"
        case .missingRequiredField(let field):
            "Missing required field: \(field)"
        case .parseError(let detail):
            "Parse error: \(detail)"
        }
    }
}
