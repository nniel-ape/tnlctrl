//
//  Deployer.swift
//  TunnelMaster
//
//  Handles deployment of proxy servers to local or remote targets.
//

import Foundation

@MainActor
final class Deployer {
    private let state: WizardState
    private let dockerManager = DockerManager.shared
    private let sshClient = SSHClient.shared

    init(state: WizardState) {
        self.state = state
    }

    // MARK: - Deploy to Existing Server

    /// Deploys a new service to an existing server.
    /// Returns only the Service - caller is responsible for updating the Server record.
    func deployToExisting(server: Server) async throws -> Service {
        let settings = state.buildDeploymentSettings()

        guard let template = ProtocolTemplates.template(for: state.selectedProtocol) else {
            throw DeployerError.unsupportedProtocol
        }

        let baseService: Service = switch server.deploymentTarget {
        case .local:
            try await deployLocal(template: template, settings: settings)
        case .remote:
            try await deployRemote(template: template, settings: settings)
        }

        // Update Service with source and serverId
        var service = baseService
        service.source = .created
        service.serverId = server.id

        return service
    }

    // MARK: - Deploy New Server

    func deploy() async throws -> (Service, Server) {
        let settings = state.buildDeploymentSettings()

        guard let template = ProtocolTemplates.template(for: state.selectedProtocol) else {
            throw DeployerError.unsupportedProtocol
        }

        let baseService: Service = switch state.deploymentTarget {
        case .local:
            try await deployLocal(template: template, settings: settings)
        case .remote:
            try await deployRemote(template: template, settings: settings)
        }

        // Create Server record
        let server = Server(
            name: state.effectiveServerName,
            host: state.deploymentTarget == .local ? "localhost" : state.sshHost,
            sshPort: state.sshPort,
            sshUsername: state.sshUsername,
            sshKeyPath: state.sshKeyPath.isEmpty ? nil : state.sshKeyPath,
            containerIds: [settings.containerName],
            serviceIds: [baseService.id],
            status: .active,
            deploymentTarget: state.deploymentTarget
        )

        // Update Service with source and serverId
        var service = baseService
        service.source = .created
        service.serverId = server.id

        return (service, server)
    }

    // MARK: - Local Deployment

    private func deployLocal(template: ProtocolTemplate, settings: DeploymentSettings) async throws -> Service {
        // Check Docker is available
        state.log("Checking Docker availability...")
        guard await dockerManager.isDockerAvailable() else {
            throw DeployerError.dockerNotAvailable
        }
        state.log("Docker is available")

        // Check if image exists, pull if needed
        state.log("Checking image \(template.defaultImage)...")
        if await !dockerManager.imageExists(template.defaultImage) {
            state.log("Pulling image...")
            try await dockerManager.pullImage(template.defaultImage)
        }
        state.log("Image ready")

        // Generate config
        state.log("Generating server configuration...")
        let config = template.generateServerConfig(settings: settings)

        // Determine config paths based on template type
        let (configDir, containerConfigDir, volumes, environment, command) = buildLocalConfig(
            template: template,
            settings: settings,
            config: config
        )

        // Write config if not empty (some templates use env vars only)
        if let configDir, !config.isEmpty {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let configFileName = (template as? Hysteria2Template)?.configFileName ?? "config.json"
            let configFile = configDir.appendingPathComponent(configFileName)
            try config.write(to: configFile, atomically: true, encoding: .utf8)
            state.log("Configuration saved")
        } else if config.isEmpty {
            state.log("Using environment-based configuration")
        }

        // Determine ports and protocols
        var ports: [Int: Int] = [:]
        var portProtocols: [Int: String] = [:]

        if template is Hysteria2Template {
            // Hysteria2 uses host network mode, no port mapping needed
        } else if template is WireGuardTemplate {
            // WireGuard needs UDP for VPN and TCP for web UI
            ports[settings.port] = settings.port
            ports[51821] = 51821
            portProtocols[settings.port] = "udp"
            portProtocols[51821] = "tcp"
        } else {
            // Standard TCP ports
            for port in template.requiredPorts {
                ports[settings.port] = settings.port
            }
        }

        // Determine network mode and capabilities
        var networkMode: String?
        var capabilities: [String] = []
        var sysctls: [String: String] = [:]

        if template is Hysteria2Template {
            networkMode = "host"
        } else if template is WireGuardTemplate {
            capabilities = ["NET_ADMIN", "SYS_MODULE"]
            sysctls = ["net.ipv4.ip_forward": "1"]
        }

        // Run container
        state.log("Starting container \(settings.containerName)...")
        _ = try await dockerManager.runContainer(
            image: template.defaultImage,
            name: settings.containerName,
            ports: ports,
            portProtocols: portProtocols,
            environment: environment,
            volumes: volumes,
            networkMode: networkMode,
            capabilities: capabilities,
            sysctls: sysctls,
            command: command
        )

        // Wait a moment for container to start
        try await Task.sleep(for: .seconds(2))

        // Check container is running
        let status = await dockerManager.getContainerStatus(name: settings.containerName)
        guard status == .running else {
            let logs = await dockerManager.getContainerLogs(name: settings.containerName, tail: 20)
            state.log("Container logs:\n\(logs)")
            throw DeployerError.containerFailed("Container exited immediately. Check logs for details.")
        }
        state.log("Container started successfully")

        // Generate client service
        state.log("Generating client configuration...")
        let service = template.generateClientService(settings: settings)
        state.log("Deployment complete!")

        return service
    }

    /// Build config paths and volumes based on template type
    private func buildLocalConfig(
        template: ProtocolTemplate,
        settings: DeploymentSettings,
        config: String
    ) -> (configDir: URL?, containerConfigDir: String, volumes: [String: String], environment: [String: String], command: [String]) {
        if let hysteriaTemplate = template as? Hysteria2Template {
            let configDir = FileManager.default.temporaryDirectory.appendingPathComponent("hysteria-\(settings.containerName)")
            return (
                configDir: configDir,
                containerConfigDir: "/etc/hysteria",
                volumes: [configDir.path: "/etc/hysteria:ro"],
                environment: [:],
                command: ["server", "-c", "/etc/hysteria/hysteria.yaml"]
            )
        } else if let wgTemplate = template as? WireGuardTemplate {
            let configDir = FileManager.default.temporaryDirectory.appendingPathComponent("wireguard-\(settings.containerName)")
            return (
                configDir: nil, // WireGuard uses env vars
                containerConfigDir: "/etc/wireguard",
                volumes: [configDir.path: "/etc/wireguard"],
                environment: wgTemplate.generateEnvironment(settings: settings),
                command: []
            )
        } else {
            // Standard sing-box based templates
            let configDir = FileManager.default.temporaryDirectory.appendingPathComponent("sing-box-\(settings.containerName)")
            return (
                configDir: configDir,
                containerConfigDir: "/etc/sing-box",
                volumes: [configDir.path: "/etc/sing-box:ro"],
                environment: [:],
                command: ["run", "-c", "/etc/sing-box/config.json"]
            )
        }
    }

    // MARK: - Remote Deployment

    private func deployRemote(template: ProtocolTemplate, settings: DeploymentSettings) async throws -> Service {
        let keyPath = state.sshKeyPath.isEmpty ? nil : state.sshKeyPath

        // Test SSH connection
        state.log("Connecting to \(state.sshHost)...")
        do {
            try await sshClient.testConnection(
                host: state.sshHost,
                port: state.sshPort,
                username: state.sshUsername,
                privateKeyPath: keyPath
            )
        } catch {
            throw DeployerError.sshConnectionFailed(error.localizedDescription)
        }
        state.log("SSH connection successful")

        // Check Docker is installed
        state.log("Checking Docker on remote server...")
        let dockerInstalled = await sshClient.isDockerInstalled(
            host: state.sshHost,
            port: state.sshPort,
            username: state.sshUsername,
            privateKeyPath: keyPath
        )

        guard dockerInstalled else {
            throw DeployerError.dockerNotAvailable
        }
        state.log("Docker is available on remote server")

        // Generate config
        state.log("Generating server configuration...")
        let config = template.generateServerConfig(settings: settings)

        // Determine remote paths based on template type
        let (remoteConfigDir, configFileName) = buildRemoteConfigPaths(template: template, settings: settings)

        // Create config directory
        state.log("Uploading configuration...")
        _ = try await sshClient.execute(
            command: "mkdir -p \(remoteConfigDir)",
            host: state.sshHost,
            port: state.sshPort,
            username: state.sshUsername,
            privateKeyPath: keyPath
        )

        // Write config via SSH if not using environment vars
        if !config.isEmpty {
            let escapedConfig = config.replacingOccurrences(of: "'", with: "'\\''")
            _ = try await sshClient.execute(
                command: "echo '\(escapedConfig)' > \(remoteConfigDir)/\(configFileName)",
                host: state.sshHost,
                port: state.sshPort,
                username: state.sshUsername,
                privateKeyPath: keyPath
            )
            state.log("Configuration uploaded")
        } else {
            state.log("Using environment-based configuration")
        }

        // Pull image
        state.log("Pulling image \(template.defaultImage)...")
        _ = try await sshClient.runDockerRemotely(
            command: "pull \(template.defaultImage)",
            host: state.sshHost,
            port: state.sshPort,
            username: state.sshUsername,
            privateKeyPath: keyPath
        )
        state.log("Image ready")

        // Build Docker run command with correct volume path
        var dockerArgs = template.generateDockerRunArgs(settings: settings)

        // Update volume path to use remote config directory
        dockerArgs = dockerArgs.map { arg in
            if arg.contains("/etc/sing-box") {
                return arg.replacingOccurrences(of: "/etc/sing-box", with: remoteConfigDir)
            } else if arg.contains("/etc/hysteria-\(settings.containerName)") {
                return arg.replacingOccurrences(of: "/etc/hysteria-\(settings.containerName)", with: remoteConfigDir)
            } else if arg.contains("/etc/wireguard-\(settings.containerName)") {
                return arg.replacingOccurrences(of: "/etc/wireguard-\(settings.containerName)", with: remoteConfigDir)
            }
            return arg
        }

        let dockerCommand = "run " + dockerArgs.joined(separator: " ")

        // Run container
        state.log("Starting container...")
        _ = try await sshClient.runDockerRemotely(
            command: dockerCommand,
            host: state.sshHost,
            port: state.sshPort,
            username: state.sshUsername,
            privateKeyPath: keyPath
        )

        // Wait and verify
        try await Task.sleep(for: .seconds(2))

        let statusOutput = try await sshClient.runDockerRemotely(
            command: "inspect --format '{{.State.Status}}' \(settings.containerName)",
            host: state.sshHost,
            port: state.sshPort,
            username: state.sshUsername,
            privateKeyPath: keyPath
        )

        guard statusOutput.trimmingCharacters(in: .whitespacesAndNewlines) == "running" else {
            throw DeployerError.containerFailed("Container is not running. Status: \(statusOutput)")
        }
        state.log("Container started successfully")

        // Generate client service with correct server address
        state.log("Generating client configuration...")
        var remoteSettings = settings
        remoteSettings.serverHost = state.sshHost
        let service = template.generateClientService(settings: remoteSettings)
        state.log("Deployment complete!")

        return service
    }

    /// Build remote config paths based on template type
    private func buildRemoteConfigPaths(
        template: ProtocolTemplate,
        settings: DeploymentSettings
    ) -> (configDir: String, configFileName: String) {
        if template is Hysteria2Template {
            return ("/etc/hysteria-\(settings.containerName)", "hysteria.yaml")
        } else if template is WireGuardTemplate {
            return ("/etc/wireguard-\(settings.containerName)", "")
        } else {
            return ("/etc/sing-box-\(settings.containerName)", "config.json")
        }
    }
}

// MARK: - Dictionary Extension

extension Dictionary {
    func mapKeys<NewKey: Hashable>(_ transform: (Key) -> NewKey) -> [NewKey: Value] {
        [NewKey: Value](uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}

// MARK: - Errors

enum DeployerError: LocalizedError {
    case unsupportedProtocol
    case dockerNotAvailable
    case sshConnectionFailed(String)
    case containerFailed(String)
    case configurationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedProtocol:
            "Selected protocol is not supported for deployment"
        case .dockerNotAvailable:
            "Docker is not available. Make sure Docker Desktop or colima is running."
        case let .sshConnectionFailed(message):
            "SSH connection failed: \(message)"
        case let .containerFailed(message):
            "Container deployment failed: \(message)"
        case let .configurationFailed(message):
            "Configuration error: \(message)"
        }
    }
}
