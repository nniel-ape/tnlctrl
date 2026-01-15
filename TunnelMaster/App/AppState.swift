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
    var servers: [Server] = []
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

    var importedServices: [Service] {
        services.filter { $0.source == .imported }
    }

    var createdServices: [Service] {
        services.filter { $0.source == .created }
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
            servers = try await ServiceStore.shared.loadServers()
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

    // MARK: - Server Management

    func saveServers() {
        Task {
            do {
                try await ServiceStore.shared.saveServers(servers)
            } catch {
                logger.error("Failed to save servers: \(error)")
            }
        }
    }

    func addServer(_ server: Server) {
        servers.append(server)
        saveServers()
    }

    func updateServer(_ server: Server) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveServers()
        }
    }

    func deleteServer(id: UUID) {
        servers.removeAll { $0.id == id }
        saveServers()
    }

    func deleteServer(_ server: Server) {
        deleteServer(id: server.id)
    }
}
