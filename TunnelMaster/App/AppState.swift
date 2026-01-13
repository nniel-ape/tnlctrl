//
//  AppState.swift
//  TunnelMaster
//

import SwiftUI

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
            try await tunnelManager.start(services: services, tunnelConfig: tunnelConfig)
        } catch {
            print("Failed to connect: \(error)")
        }
    }

    func disconnect() async {
        do {
            try await tunnelManager.stop()
        } catch {
            print("Failed to disconnect: \(error)")
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
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    func saveServices() {
        Task {
            do {
                try await ServiceStore.shared.saveServices(services)
            } catch {
                print("Failed to save services: \(error)")
            }
        }
    }

    func saveTunnelConfig() {
        Task {
            do {
                try await ServiceStore.shared.saveTunnelConfig(tunnelConfig)
            } catch {
                print("Failed to save tunnel config: \(error)")
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
