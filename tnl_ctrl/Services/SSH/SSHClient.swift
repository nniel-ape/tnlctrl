//
//  SSHClient.swift
//  tnl_ctrl
//
//  Execute commands on remote servers via SSH using system ssh binary.
//

import Foundation

actor SSHClient {
    static let shared = SSHClient()

    private let sshPath = "/usr/bin/ssh"
    private let scpPath = "/usr/bin/scp"

    private init() {}

    // MARK: - Connection Test

    func testConnection(host: String, port: Int = 22, username: String, privateKeyPath: String? = nil) async throws {
        let args = buildSSHArgs(
            host: host,
            port: port,
            username: username,
            privateKeyPath: privateKeyPath,
            command: "echo connected"
        )

        let result = try await executeSSH(args, timeout: 10)
        guard result.trimmingCharacters(in: .whitespacesAndNewlines) == "connected" else {
            throw SSHError.connectionFailed("Unexpected response")
        }
    }

    // MARK: - Command Execution

    func execute(
        command: String,
        host: String,
        port: Int = 22,
        username: String,
        privateKeyPath: String? = nil,
        timeout: TimeInterval = 60
    ) async throws -> String {
        let args = buildSSHArgs(
            host: host,
            port: port,
            username: username,
            privateKeyPath: privateKeyPath,
            command: command
        )

        return try await executeSSH(args, timeout: timeout)
    }

    // MARK: - File Transfer

    func uploadFile(
        localPath: String,
        remotePath: String,
        host: String,
        port: Int = 22,
        username: String,
        privateKeyPath: String? = nil
    ) async throws {
        var args = ["-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes"]

        if let keyPath = privateKeyPath {
            args.append(contentsOf: ["-i", keyPath])
        }

        if port != 22 {
            args.append(contentsOf: ["-P", "\(port)"])
        }

        args.append(localPath)
        args.append("\(username)@\(host):\(remotePath)")

        try await executeSCP(args, timeout: 120)
    }

    func downloadFile(
        remotePath: String,
        localPath: String,
        host: String,
        port: Int = 22,
        username: String,
        privateKeyPath: String? = nil
    ) async throws {
        var args = ["-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes"]

        if let keyPath = privateKeyPath {
            args.append(contentsOf: ["-i", keyPath])
        }

        if port != 22 {
            args.append(contentsOf: ["-P", "\(port)"])
        }

        args.append("\(username)@\(host):\(remotePath)")
        args.append(localPath)

        try await executeSCP(args, timeout: 120)
    }

    // MARK: - Docker on Remote

    func isDockerInstalled(
        host: String,
        port: Int = 22,
        username: String,
        privateKeyPath: String? = nil
    ) async -> Bool {
        do {
            let result = try await execute(
                command: "docker --version",
                host: host,
                port: port,
                username: username,
                privateKeyPath: privateKeyPath,
                timeout: 10
            )
            return result.contains("Docker version")
        } catch {
            return false
        }
    }

    func runDockerRemotely(
        command: String,
        host: String,
        port: Int = 22,
        username: String,
        privateKeyPath: String? = nil
    ) async throws -> String {
        try await execute(
            command: "docker \(command)",
            host: host,
            port: port,
            username: username,
            privateKeyPath: privateKeyPath,
            timeout: 120
        )
    }

    // MARK: - Shell Quoting

    /// POSIX-safe shell quoting: wraps value in single quotes, escaping embedded single quotes.
    /// `foo'bar` → `'foo'\''bar'`
    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Helpers

    private func buildSSHArgs(
        host: String,
        port: Int,
        username: String,
        privateKeyPath: String?,
        command: String
    ) -> [String] {
        var args = ["-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes"]

        if let keyPath = privateKeyPath {
            args.append(contentsOf: ["-i", keyPath])
        }

        if port != 22 {
            args.append(contentsOf: ["-p", "\(port)"])
        }

        args.append("\(username)@\(host)")
        args.append(command)

        return args
    }

    private func executeSSH(_ args: [String], timeout: TimeInterval) async throws -> String {
        try await executeCommand(sshPath, args: args, timeout: timeout)
    }

    private func executeSCP(_ args: [String], timeout: TimeInterval) async throws {
        _ = try await executeCommand(scpPath, args: args, timeout: timeout)
    }

    private func executeCommand(_ path: String, args: [String], timeout: TimeInterval) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Create a task for the process execution with timeout
        return try await withCheckedThrowingContinuation { continuation in
            let workItem = DispatchWorkItem {
                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus != 0 {
                        let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: SSHError.commandFailed(errorString.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        let output = String(data: outputData, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    }
                } catch {
                    continuation.resume(throwing: SSHError.connectionFailed(error.localizedDescription))
                }
            }

            // Schedule timeout
            let timeoutWorkItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }

            DispatchQueue.global().async(execute: workItem)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
        }
    }
}

// MARK: - SSH Configuration

struct SSHConnectionConfig {
    let host: String
    let port: Int
    let username: String
    let privateKeyPath: String?

    init(host: String, port: Int = 22, username: String, privateKeyPath: String? = nil) {
        self.host = host
        self.port = port
        self.username = username
        self.privateKeyPath = privateKeyPath
    }
}

// MARK: - Errors

enum SSHError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case commandFailed(String)
    case timeout
    case fileTransferFailed(String)

    var errorDescription: String? {
        switch self {
        case let .connectionFailed(message):
            "SSH connection failed: \(message)"
        case .authenticationFailed:
            "SSH authentication failed. Check your credentials."
        case let .commandFailed(message):
            "SSH command failed: \(message)"
        case .timeout:
            "SSH connection timed out"
        case let .fileTransferFailed(message):
            "File transfer failed: \(message)"
        }
    }
}
