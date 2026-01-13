//
//  AppState.swift
//  TunnelMaster
//

import SwiftUI

@Observable
final class AppState {
    // MARK: - Connection State

    var isConnected = false
    var isConnecting = false
    var activeServiceId: UUID?

    // MARK: - Data

    var services: [Service] = []
    var tunnelConfig: TunnelConfig = .default

    // MARK: - Computed

    var activeService: Service? {
        guard let id = activeServiceId else { return nil }
        return services.first { $0.id == id }
    }

    var enabledServices: [Service] {
        services.filter(\.isEnabled)
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
