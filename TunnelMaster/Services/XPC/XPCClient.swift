//
//  XPCClient.swift
//  TunnelMaster
//
//  Client for communicating with the privileged helper.
//

import Foundation

@MainActor
final class XPCClient {
    static let shared = XPCClient()

    private var connection: NSXPCConnection?

    private init() {}

    // MARK: - Connection Management

    private func getConnection() throws -> NSXPCConnection {
        if let connection = connection {
            return connection
        }

        let conn = NSXPCConnection(machServiceName: helperMachServiceName, options: .privileged)
        conn.remoteObjectInterface = createHelperInterface()

        conn.invalidationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleInvalidation()
            }
        }

        conn.interruptionHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleInterruption()
            }
        }

        conn.resume()
        connection = conn

        return conn
    }

    private func handleInvalidation() {
        connection = nil
    }

    private func handleInterruption() {
        // Connection was interrupted, will reconnect on next call
    }

    private func getProxy() throws -> HelperProtocol {
        let conn = try getConnection()
        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
            // Error handler is called on a background thread
            print("XPC error: \(error)")
        }) as? HelperProtocol else {
            throw XPCError.connectionFailed
        }
        return proxy
    }

    // MARK: - Public API

    func startTunnel(configJSON: String) async throws {
        let proxy = try getProxy()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.startTunnel(configJSON: configJSON) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: XPCError.operationFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func stopTunnel() async throws {
        let proxy = try getProxy()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.stopTunnel { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: XPCError.operationFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func getStatus() async throws -> TunnelStatus {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getStatus { isRunning, statusCode in
                let status = TunnelStatus(rawValue: statusCode) ?? (isRunning ? .running : .stopped)
                continuation.resume(returning: status)
            }
        }
    }

    func reloadConfig(configJSON: String) async throws {
        let proxy = try getProxy()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.reloadConfig(configJSON: configJSON) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: XPCError.operationFailed(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func getVersion() async throws -> String {
        let proxy = try getProxy()

        return await withCheckedContinuation { continuation in
            proxy.getVersion { version in
                continuation.resume(returning: version)
            }
        }
    }

    func isHelperResponding() async -> Bool {
        do {
            _ = try await getVersion()
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum XPCError: LocalizedError {
    case connectionFailed
    case operationFailed(String)
    case helperNotInstalled

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            "Failed to connect to helper"
        case .operationFailed(let message):
            "Helper operation failed: \(message)"
        case .helperNotInstalled:
            "Privileged helper is not installed"
        }
    }
}
