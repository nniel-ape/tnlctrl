//
//  AppState.swift
//  TunnelMaster
//

import OSLog
import SwiftUI

private let logger = Logger(subsystem: "nniel.TunnelMaster", category: "AppState")

@MainActor
@Observable
final class AppState {
    // MARK: - Tunnel Manager

    let tunnelManager = TunnelManager.shared
    let helperInstaller = HelperInstaller.shared

    // MARK: - Connection State

    var activeServiceId: UUID?

    // MARK: - Data

    var services: [Service] = []
    var tunnelConfig: TunnelConfig = .default
    var settings: AppSettings = .default

    // MARK: - Computed

    var isConnected: Bool {
        tunnelManager.status.isConnected
    }

    var isTransitioning: Bool {
        tunnelManager.isTransitioning
    }

    var tunnelStatus: TunnelStatus {
        tunnelManager.status
    }

    var tunnelError: String? {
        tunnelManager.error
    }

    var activeService: Service? {
        guard let id = activeServiceId else { return nil }
        return services.first { $0.id == id }
    }

    var enabledServices: [Service] {
        services.filter(\.isEnabled)
    }

    // MARK: - Tunnel Control

    func connect() async {
        do {
            try await tunnelManager.start(
                services: services,
                tunnelConfig: tunnelConfig,
                enableLogs: settings.enableSingBoxLogs
            )
        } catch {
            logger.error("Failed to connect: \(error)")
        }
    }

    func disconnect() async {
        do {
            try await tunnelManager.stop()
        } catch {
            logger.error("Failed to disconnect: \(error)")
        }
    }

    func toggleConnection() async {
        if isConnected {
            await disconnect()
        } else {
            await connect()
        }
    }

    // MARK: - Persistence

    func load() async {
        do {
            services = try await ServiceStore.shared.loadServices()
            tunnelConfig = try await ServiceStore.shared.loadTunnelConfig()
            settings = try await ServiceStore.shared.loadSettings()
        } catch {
            logger.error("Failed to load data: \(error)")
        }
    }

    func saveSettings() {
        Task {
            do {
                try await ServiceStore.shared.saveSettings(settings)
            } catch {
                logger.error("Failed to save settings: \(error)")
            }
        }
    }

    func saveServices() {
        Task {
            do {
                try await ServiceStore.shared.saveServices(services)
            } catch {
                logger.error("Failed to save services: \(error)")
            }
        }
    }

    func saveTunnelConfig() {
        Task {
            do {
                try await ServiceStore.shared.saveTunnelConfig(tunnelConfig)
            } catch {
                logger.error("Failed to save tunnel config: \(error)")
            }
        }
    }

    // MARK: - Service Management

    func addService(_ service: Service) {
        services.append(service)
        saveServices()
    }

    func updateService(_ service: Service) {
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index] = service
            saveServices()
        }
    }

    func deleteService(id: UUID) {
        services.removeAll { $0.id == id }
        if activeServiceId == id {
            activeServiceId = nil
        }
        saveServices()
    }

    func deleteService(_ service: Service) {
        deleteService(id: service.id)
    }
}
