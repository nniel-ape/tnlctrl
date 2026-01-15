//
//  TunnelManager.swift
//  TunnelMaster
//
//  Manages tunnel lifecycle through XPC communication with the helper.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "nniel.TunnelMaster", category: "TunnelManager")

@Observable
@MainActor
final class TunnelManager {
    static let shared = TunnelManager()

    private(set) var status: TunnelStatus = .stopped {
        didSet {
            if status != oldValue {
                NotificationService.shared.notifyStatusChange(status)
            }
        }
    }

    private(set) var error: String?
    private(set) var isTransitioning = false

    private let xpcClient = XPCClient.shared
    private let helperInstaller = HelperInstaller.shared
    private let notificationService = NotificationService.shared

    private var statusCheckTask: Task<Void, Never>?

    private init() {}

    // MARK: - Start

    func start(services: [Service], tunnelConfig: TunnelConfig, enableLogs: Bool = false) async throws {
        guard helperInstaller.status == .installed else {
            throw TunnelManagerError.helperNotInstalled
        }

        guard !isTransitioning else {
            throw TunnelManagerError.alreadyTransitioning
        }

        let enabledServices = services.filter(\.isEnabled)
        guard !enabledServices.isEmpty else {
            throw TunnelManagerError.noEnabledServices
        }

        isTransitioning = true
        error = nil
        status = .connecting

        do {
            // Build sing-box config
            let builder = SingBoxConfigBuilder(services: enabledServices, tunnelConfig: tunnelConfig)
            let configJSON = try await builder.build()

            // Debug: log generated config
            logger.debug("Generated sing-box config: \(configJSON, privacy: .private)")

            // Start tunnel via XPC
            try await xpcClient.startTunnel(configJSON: configJSON, enableLogs: enableLogs)

            status = .running
            startStatusPolling()
        } catch {
            self.error = error.localizedDescription
            status = .error
            throw error
        }

        isTransitioning = false
    }

    // MARK: - Stop

    func stop() async throws {
        guard !isTransitioning else {
            throw TunnelManagerError.alreadyTransitioning
        }

        isTransitioning = true
        error = nil
        status = .disconnecting

        do {
            try await xpcClient.stopTunnel()
            status = .stopped
            stopStatusPolling()
        } catch {
            self.error = error.localizedDescription
            status = .error
            throw error
        }

        isTransitioning = false
    }

    // MARK: - Reload Config

    func reload(services: [Service], tunnelConfig: TunnelConfig) async throws {
        guard status == .running else {
            throw TunnelManagerError.notRunning
        }

        let enabledServices = services.filter(\.isEnabled)
        guard !enabledServices.isEmpty else {
            throw TunnelManagerError.noEnabledServices
        }

        do {
            let builder = SingBoxConfigBuilder(services: enabledServices, tunnelConfig: tunnelConfig)
            let configJSON = try await builder.build()
            try await xpcClient.reloadConfig(configJSON: configJSON)
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Status Polling

    func refreshStatus() async {
        do {
            let newStatus = try await xpcClient.getStatus()
            if status != .connecting, status != .disconnecting {
                status = newStatus
            }
        } catch {
            if status == .running {
                status = .error
                self.error = "Lost connection to helper"
            }
        }
    }

    private func startStatusPolling() {
        stopStatusPolling()
        statusCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await refreshStatus()
            }
        }
    }

    private func stopStatusPolling() {
        statusCheckTask?.cancel()
        statusCheckTask = nil
    }

    // MARK: - Helper Info

    func getHelperVersion() async -> String? {
        try? await xpcClient.getVersion()
    }
}

// MARK: - Errors

enum TunnelManagerError: LocalizedError {
    case helperNotInstalled
    case alreadyTransitioning
    case noEnabledServices
    case notRunning

    var errorDescription: String? {
        switch self {
        case .helperNotInstalled:
            "Privileged helper is not installed. Install it from Settings > General."
        case .alreadyTransitioning:
            "Tunnel is already starting or stopping"
        case .noEnabledServices:
            "No enabled proxy services configured"
        case .notRunning:
            "Tunnel is not running"
        }
    }
}
