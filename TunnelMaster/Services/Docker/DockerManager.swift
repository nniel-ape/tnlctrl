//
//  DockerManager.swift
//  TunnelMaster
//
//  Manages local Docker containers via CLI.
//

import Foundation

actor DockerManager {
    static let shared = DockerManager()

    private init() {}

    // MARK: - Docker Availability

    func isDockerAvailable() async -> Bool {
        do {
            let result = try await executeDocker(["info", "--format", "{{.ServerVersion}}"])
            return !result.isEmpty
        } catch {
            return false
        }
    }

    func getDockerVersion() async -> String? {
        try? await executeDocker(["version", "--format", "{{.Server.Version}}"])
    }

    // MARK: - Container Management

    func runContainer(
        image: String,
        name: String,
        ports: [Int: Int] = [:], // hostPort: containerPort
        portProtocols: [Int: String] = [:], // port: protocol (tcp/udp)
        environment: [String: String] = [:],
        volumes: [String: String] = [:], // hostPath: containerPath
        detached: Bool = true,
        restart: RestartPolicy = .unless_stopped,
        networkMode: String? = nil, // "host", "bridge", etc.
        capabilities: [String] = [], // "NET_ADMIN", "SYS_MODULE"
        sysctls: [String: String] = [:], // "net.ipv4.ip_forward": "1"
        command: [String] = [] // Command args after image
    ) async throws -> String {
        var args = ["run"]

        if detached {
            args.append("-d")
        }

        args.append("--name")
        args.append(name)

        args.append("--restart")
        args.append(restart.rawValue)

        // Add network mode
        if let networkMode {
            args.append("--network")
            args.append(networkMode)
        }

        // Add capabilities
        for cap in capabilities {
            args.append("--cap-add")
            args.append(cap)
        }

        // Add sysctls
        for (key, value) in sysctls {
            args.append("--sysctl")
            args.append("\(key)=\(value)")
        }

        // Add port mappings (skip if host network mode)
        if networkMode != "host" {
            for (host, container) in ports {
                let proto = portProtocols[host] ?? "tcp"
                args.append("-p")
                args.append("\(host):\(container)/\(proto)")
            }
        }

        // Add environment variables
        for (key, value) in environment.sorted(by: { $0.key < $1.key }) {
            args.append("-e")
            args.append("\(key)=\(value)")
        }

        // Add volume mounts
        for (hostPath, containerPath) in volumes {
            args.append("-v")
            args.append("\(hostPath):\(containerPath)")
        }

        args.append(image)

        // Add command after image
        args.append(contentsOf: command)

        return try await executeDocker(args)
    }

    func stopContainer(name: String) async throws {
        _ = try await executeDocker(["stop", name])
    }

    func startContainer(name: String) async throws {
        _ = try await executeDocker(["start", name])
    }

    func removeContainer(name: String, force: Bool = false) async throws {
        var args = ["rm"]
        if force {
            args.append("-f")
        }
        args.append(name)
        _ = try await executeDocker(args)
    }

    func getContainerStatus(name: String) async -> ContainerStatus {
        do {
            let result = try await executeDocker([
                "inspect",
                "--format", "{{.State.Status}}",
                name
            ])

            switch result.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "running": return .running
            case "paused": return .paused
            case "exited": return .exited
            case "created": return .created
            case "restarting": return .restarting
            default: return .unknown
            }
        } catch {
            return .notFound
        }
    }

    func listContainers(all: Bool = false) async -> [ContainerInfo] {
        var args = ["ps", "--format", "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}"]
        if all {
            args.insert("-a", at: 1)
        }

        guard let result = try? await executeDocker(args) else {
            return []
        }

        return result.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0) }
            guard parts.count >= 5 else { return nil }
            return ContainerInfo(
                id: parts[0],
                name: parts[1],
                image: parts[2],
                status: parts[3],
                ports: parts[4]
            )
        }
    }

    func getContainerLogs(name: String, tail: Int = 100) async -> String {
        await (try? executeDocker(["logs", "--tail", "\(tail)", name])) ?? ""
    }

    // MARK: - Image Management

    func pullImage(_ image: String, onProgress: ((String) -> Void)? = nil) async throws {
        _ = try await executeDocker(["pull", image])
    }

    func imageExists(_ image: String) async -> Bool {
        do {
            _ = try await executeDocker(["image", "inspect", image])
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helper

    private func executeDocker(_ args: [String]) async throws -> String {
        let dockerPath = await findDockerPath()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: dockerPath)
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw DockerError.commandFailed(errorString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func findDockerPath() async -> String {
        // Check common Docker paths
        let paths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker",
            // Colima symlinks
            "/Users/\(NSUserName())/.colima/default/docker.sock"
        ]

        for path in paths where FileManager.default.fileExists(atPath: path) && !path.hasSuffix(".sock") {
            return path
        }

        // Default to docker and hope it's in PATH
        return "docker"
    }
}

// MARK: - Types

enum ContainerStatus: String, Sendable {
    case running
    case paused
    case exited
    case created
    case restarting
    case notFound
    case unknown

    var displayName: String {
        switch self {
        case .running: "Running"
        case .paused: "Paused"
        case .exited: "Stopped"
        case .created: "Created"
        case .restarting: "Restarting"
        case .notFound: "Not Found"
        case .unknown: "Unknown"
        }
    }

    var isHealthy: Bool {
        self == .running
    }
}

enum RestartPolicy: String, Sendable {
    case no
    case always
    case on_failure = "on-failure"
    case unless_stopped = "unless-stopped"
}

struct ContainerInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let image: String
    let status: String
    let ports: String

    var isRunning: Bool {
        status.lowercased().contains("up")
    }
}

// MARK: - Errors

enum DockerError: LocalizedError {
    case notInstalled
    case commandFailed(String)
    case containerNotFound(String)
    case imagePullFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            "Docker is not installed or not running"
        case let .commandFailed(message):
            "Docker command failed: \(message)"
        case let .containerNotFound(name):
            "Container '\(name)' not found"
        case let .imagePullFailed(image):
            "Failed to pull image '\(image)'"
        }
    }
}
