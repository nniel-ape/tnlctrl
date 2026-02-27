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
    var presets: [TunnelPreset] = []

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
            presets = try await ServiceStore.shared.loadPresets()
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

    // MARK: - Preset Management

    func savePresets() {
        Task {
            do {
                try await ServiceStore.shared.savePresets(presets)
            } catch {
                logger.error("Failed to save presets: \(error)")
            }
        }
    }

    func saveCurrentConfigAsPreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let preset = TunnelPreset(name: trimmed, config: tunnelConfig)
        presets.append(preset)
        savePresets()
    }

    func loadPreset(_ preset: TunnelPreset) {
        tunnelConfig.mode = preset.mode
        tunnelConfig.finalOutbound = preset.finalOutbound
        tunnelConfig.selectedServiceId = preset.selectedServiceId
        tunnelConfig.chainEnabled = preset.chainEnabled
        tunnelConfig.chain = preset.chain
        for i in 0 ..< tunnelConfig.rules.count {
            tunnelConfig.rules[i].isEnabled = preset.enabledRuleIds.contains(tunnelConfig.rules[i].id)
        }
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        savePresets()
    }

    func renamePreset(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let index = presets.firstIndex(where: { $0.id == id }) {
            presets[index].name = trimmed
            savePresets()
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

    func deleteService(id: UUID) async {
        guard let service = services.first(where: { $0.id == id }) else { return }
        let server = service.serverId.flatMap { sid in servers.first { $0.id == sid } }

        if service.source == .created {
            await cleanupContainer(for: service, server: server)
        }

        // Remove from server's tracking arrays
        if let server {
            if var updated = servers.first(where: { $0.id == server.id }) {
                updated.serviceIds.removeAll { $0 == id }
                if let containerName = service.settings["containerName"]?.stringValue {
                    updated.containerIds.removeAll { $0 == containerName }
                }
                updateServer(updated)
            }
        }

        services.removeAll { $0.id == id }
        if activeServiceId == id {
            activeServiceId = nil
        }
        saveServices()
    }

    func deleteService(_ service: Service) async {
        await deleteService(id: service.id)
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

    func deleteServer(id: UUID) async {
        guard let server = servers.first(where: { $0.id == id }) else { return }

        // Cascade-delete all services on this server
        let serverServices = services.filter { $0.serverId == id }
        for service in serverServices {
            await cleanupContainer(for: service, server: server)
        }
        services.removeAll { $0.serverId == id }

        servers.removeAll { $0.id == id }
        saveServers()
        saveServices()
    }

    func deleteServer(_ server: Server) async {
        await deleteServer(id: server.id)
    }

    // MARK: - Container Cleanup

    /// Best-effort cleanup of a Docker container associated with a service.
    private func cleanupContainer(for service: Service, server: Server?) async {
        guard let containerName = service.settings["containerName"]?.stringValue,
              !containerName.isEmpty
        else { return }

        if server?.deploymentTarget == .local || server == nil {
            // Local Docker cleanup
            do {
                try await DockerManager.shared.stopContainer(name: containerName)
            } catch {
                logger.warning("Failed to stop container \(containerName): \(error)")
            }
            do {
                try await DockerManager.shared.removeContainer(name: containerName, force: true)
            } catch {
                logger.warning("Failed to remove container \(containerName): \(error)")
            }
            // Remove local config directory
            let configDir = Deployer.containerConfigDir
            for prefix in ["sing-box-", "hysteria-", "wireguard-"] {
                let dir = configDir.appendingPathComponent("\(prefix)\(containerName)")
                try? FileManager.default.removeItem(at: dir)
            }
        } else if let server {
            // Remote cleanup (best-effort)
            do {
                _ = try await SSHClient.shared.runDockerRemotely(
                    command: "rm -f \(SSHClient.shellQuote(containerName))",
                    host: server.host,
                    port: server.sshPort,
                    username: server.sshUsername,
                    privateKeyPath: server.sshKeyPath
                )
            } catch {
                logger.warning("Failed to clean up remote container \(containerName): \(error)")
            }
        }
    }
}
