//
//  MockKeychainManager.swift
//  tnl_ctrl_tests
//

import Foundation
@testable import tnl_ctrl

/// Mock KeychainManager for testing without actual Keychain access
actor MockKeychainManager: KeychainManaging {
    var storage: [String: String] = [:]
    private var refCounter = 0

    func save(_ value: String, for key: String) throws {
        storage[key] = value
    }

    func get(_ key: String) throws -> String? {
        storage[key]
    }

    func delete(_ key: String) throws {
        storage.removeValue(forKey: key)
    }

    func deleteAll() throws {
        storage.removeAll()
    }

    func exists(_ key: String) -> Bool {
        storage[key] != nil
    }

    func generateCredentialRef() -> String {
        refCounter += 1
        return "mock-ref-\(refCounter)"
    }

    // MARK: - Test Helpers

    func reset() {
        storage.removeAll()
        refCounter = 0
    }

    func preloadCredential(_ value: String, ref: String) {
        storage[ref] = value
    }
}
