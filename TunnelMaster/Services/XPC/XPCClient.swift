//
//  XPCClient.swift
//  TunnelMaster
//
//  Client for communicating with the privileged helper.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "nniel.TunnelMaster", category: "XPCClient")

@MainActor
final class XPCClient {
    static let shared = XPCClient()

    private var connection: NSXPCConnection?

    private init() {}

    // MARK: - Connection Management

    private func getConnection() throws -> NSXPCConnection {
        if let connection {
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

    /// Resets the XPC connection, forcing a fresh connection on next call.
    /// Call this after helper installation to avoid stale connections.
    func resetConnection() {
        connection?.invalidate()
        connection = nil
    }

    /// Executes an async operation with a timeout.
    private func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw XPCError.connectionFailed
            }
            guard let result = try await group.next() else {
                throw XPCError.connectionFailed
            }
            group.cancelAll()
            return result
        }
    }

    private func getProxy() throws -> HelperProtocol {
        let conn = try getConnection()
        guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
            // Error handler is called on a background thread
            logger.error("XPC error: \(error)")
        }) as? HelperProtocol
        else {
            throw XPCError.connectionFailed
        }
        return proxy
    }

    // MARK: - Public API

    func startTunnel(configJSON: String, enableLogs: Bool) async throws {
        let proxy = try getProxy()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.startTunnel(configJSON: configJSON, enableLogs: enableLogs) { success, errorMessage in
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

    func isHelperResponding(timeout: Double = 5.0) async -> Bool {
        do {
            _ = try await withTimeout(seconds: timeout) { [self] in
                try await getVersion()
            }
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
        case let .operationFailed(message):
            "Helper operation failed: \(message)"
        case .helperNotInstalled:
            "Privileged helper is not installed"
        }
    }
}
