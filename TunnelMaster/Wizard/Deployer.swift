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

    // MARK: - Deploy

    func deploy() async throws -> Service {
        let settings = state.buildDeploymentSettings()

        guard let template = ProtocolTemplates.template(for: state.selectedProtocol) else {
            throw DeployerError.unsupportedProtocol
        }

        switch state.deploymentTarget {
        case .local:
            return try await deployLocal(template: template, settings: settings)
        case .remote:
            return try await deployRemote(template: template, settings: settings)
        }
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

        // Write config to temp file
        let configDir = FileManager.default.temporaryDirectory.appendingPathComponent("sing-box-\(settings.containerName)")
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let configFile = configDir.appendingPathComponent("config.json")
        try config.write(to: configFile, atomically: true, encoding: .utf8)
        state.log("Configuration saved")

        // Run container
        state.log("Starting container \(settings.containerName)...")
        let ports = Dictionary(uniqueKeysWithValues: template.requiredPorts.map { ($0, $0) })

        _ = try await dockerManager.runContainer(
            image: template.defaultImage,
            name: settings.containerName,
            ports: ports.mapKeys { _ in settings.port },
            volumes: [configDir.path: "/etc/sing-box"]
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

        // Create config directory and upload config
        state.log("Uploading configuration...")
        let remoteConfigDir = "/etc/sing-box-\(settings.containerName)"
        _ = try await sshClient.execute(
            command: "mkdir -p \(remoteConfigDir)",
            host: state.sshHost,
            port: state.sshPort,
            username: state.sshUsername,
            privateKeyPath: keyPath
        )

        // Write config via SSH (echo to file)
        let escapedConfig = config.replacingOccurrences(of: "'", with: "'\\''")
        _ = try await sshClient.execute(
            command: "echo '\(escapedConfig)' > \(remoteConfigDir)/config.json",
            host: state.sshHost,
            port: state.sshPort,
            username: state.sshUsername,
            privateKeyPath: keyPath
        )
        state.log("Configuration uploaded")

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

        // Build Docker run command
        let dockerArgs = template.generateDockerRunArgs(settings: settings)
        let dockerCommand = "run " + dockerArgs.dropFirst().joined(separator: " ") // Remove -d as it's in args

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
