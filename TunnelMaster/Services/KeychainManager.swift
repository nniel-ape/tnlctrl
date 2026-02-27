//
//  KeychainManager.swift
//  TunnelMaster
//

import Foundation
import OSLog
import Security

private let logger = Logger(subsystem: "nniel.TunnelMaster", category: "KeychainManager")

// MARK: - Protocol

protocol KeychainManaging: Actor, Sendable {
    func save(_ value: String, for key: String) throws
    func get(_ key: String) throws -> String?
    func delete(_ key: String) throws
    func deleteAll() throws
    func exists(_ key: String) -> Bool
    func generateCredentialRef() -> String
}

// MARK: - Implementation

actor KeychainManager: KeychainManaging {
    static let shared = KeychainManager()

    private let service = "nniel.TunnelMaster"

    private init() {}

    // MARK: - Public API

    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first
        try? delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func get(_ key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8)
            else {
                throw KeychainError.decodingFailed
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            logger.error("KeychainManager: Failed to read key: \(key, privacy: .public), status: \(status)")
            throw KeychainError.readFailed(status)
        }
    }

    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func exists(_ key: String) -> Bool {
        (try? get(key)) != nil
    }

    func generateCredentialRef() -> String {
        UUID().uuidString
    }

    // MARK: - Bulk Operations

    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Failed to encode value for keychain storage"
        case .decodingFailed:
            "Failed to decode value from keychain"
        case let .saveFailed(status):
            "Failed to save to keychain: \(status)"
        case let .readFailed(status):
            "Failed to read from keychain: \(status)"
        case let .deleteFailed(status):
            "Failed to delete from keychain: \(status)"
        }
    }
}
