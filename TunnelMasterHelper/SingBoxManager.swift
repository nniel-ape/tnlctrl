//
//  SingBoxManager.swift
//  TunnelMasterHelper
//
//  Manages the sing-box process lifecycle.
//

import Foundation

actor SingBoxManager {
    private var process: Process?
    private var configPath: URL?
    private var enableLogs = false
    private var logFileHandle: FileHandle?
    private var restartCount = 0
    private let maxRestarts = 5
    private let restartDelay: TimeInterval = 2.0

    private var singBoxPath: URL {
        // In production, this would be bundled with the helper
        // For now, look in common locations
        let bundledPath = Bundle.main.url(forResource: "sing-box", withExtension: nil)
        if let path = bundledPath, FileManager.default.fileExists(atPath: path.path) {
            return path
        }

        // Check Homebrew paths
        let homebrewPaths = [
            "/opt/homebrew/bin/sing-box", // Apple Silicon
            "/usr/local/bin/sing-box", // Intel
            "/opt/homebrew/opt/sing-box/bin/sing-box"
        ]

        for path in homebrewPaths where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        // Default fallback
        return URL(fileURLWithPath: "/opt/homebrew/bin/sing-box")
    }

    private var configDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelMasterHelper", isDirectory: true)
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    var pid: Int32? {
        guard let process, process.isRunning else { return nil }
        return process.processIdentifier
    }

    // MARK: - Lifecycle

    func start(configJSON: String, enableLogs: Bool) async throws {
        // Stop existing process if running
        if isRunning {
            await stop()
        }

        // Store logging preference
        self.enableLogs = enableLogs

        // Write config to temp file
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let configURL = configDirectory.appendingPathComponent("config.json")
        try configJSON.write(to: configURL, atomically: true, encoding: .utf8)
        configPath = configURL

        // Reset restart counter
        restartCount = 0

        // Start sing-box
        try await launchProcess()
    }

    func stop() async {
        guard let process else { return }

        NSLog("SingBoxManager: Stopping sing-box (PID: \(process.processIdentifier))")

        // Send SIGTERM for graceful shutdown
        process.terminate()

        // Wait briefly for graceful termination
        try? await Task.sleep(for: .milliseconds(500))

        // Force kill if still running
        if process.isRunning {
            process.interrupt()
        }

        // Close log file
        try? logFileHandle?.close()
        logFileHandle = nil

        self.process = nil
        restartCount = maxRestarts // Prevent auto-restart
    }

    func reload(configJSON: String) async throws {
        guard let configPath else {
            throw SingBoxError.notRunning
        }

        // Write new config
        try configJSON.write(to: configPath, atomically: true, encoding: .utf8)

        // Send SIGHUP to reload
        if let process, process.isRunning {
            kill(process.processIdentifier, SIGHUP)
            NSLog("SingBoxManager: Sent SIGHUP to sing-box for config reload")
        } else {
            // If not running, start fresh (preserve current logging preference)
            try await start(configJSON: configJSON, enableLogs: enableLogs)
        }
    }

    // MARK: - Process Management

    private func launchProcess() async throws {
        guard FileManager.default.fileExists(atPath: singBoxPath.path) else {
            throw SingBoxError.binaryNotFound(singBoxPath.path)
        }

        guard let configPath else {
            throw SingBoxError.noConfig
        }

        NSLog("SingBoxManager: Launching sing-box from \(singBoxPath.path) (logging: \(enableLogs))")

        let process = Process()
        process.executableURL = singBoxPath
        process.arguments = ["run", "-c", configPath.path]
        process.currentDirectoryURL = configDirectory

        // Set explicit environment for daemon context
        process.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/sbin",
            "HOME": NSHomeDirectory(),
            "TMPDIR": NSTemporaryDirectory()
        ]

        if enableLogs {
            // Logging enabled: capture output to file and NSLog
            let logURL = configDirectory.appendingPathComponent("sing-box.log")

            // Create/truncate log file
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: logURL)
            logFileHandle = fileHandle

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Use readabilityHandler for continuous non-blocking reads
            outputPipe.fileHandleForReading.readabilityHandler = { [weak fileHandle] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    // Write to log file
                    try? fileHandle?.write(contentsOf: data)
                    // Also log to system log
                    if let str = String(data: data, encoding: .utf8) {
                        for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                            NSLog("sing-box: %@", line)
                        }
                    }
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { [weak fileHandle] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    // Write to log file
                    try? fileHandle?.write(contentsOf: data)
                    // Also log to system log
                    if let str = String(data: data, encoding: .utf8) {
                        for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                            NSLog("sing-box [error]: %@", line)
                        }
                    }
                }
            }

            // Set up termination handler
            process.terminationHandler = { [weak self] terminatedProcess in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                let exitCode = terminatedProcess.terminationStatus
                NSLog("SingBoxManager: sing-box exited with code \(exitCode)")

                Task { [weak self] in
                    await self?.handleTermination(exitCode: exitCode)
                }
            }
        } else {
            // Logging disabled: use real pipes with drain handlers (not FileHandle.nullDevice)
            // FileHandle.nullDevice has fd -1 which can cause undefined behavior with dup2
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Drain stdout immediately to prevent pipe buffer deadlock
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                _ = handle.availableData
            }

            // Termination handler with cleanup (matches logs-on path)
            process.terminationHandler = { [weak self] terminatedProcess in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                let exitCode = terminatedProcess.terminationStatus
                NSLog("SingBoxManager: sing-box exited with code \(exitCode)")

                Task { [weak self] in
                    await self?.handleTermination(exitCode: exitCode)
                }
            }

            try process.run()
            self.process = process

            NSLog("SingBoxManager: sing-box started (PID: \(process.processIdentifier))")

            // Wait briefly to check if it started successfully
            try await Task.sleep(for: .milliseconds(500))

            if !process.isRunning {
                let stderrData = errorPipe.fileHandleForReading.availableData
                let stderrText = String(data: stderrData, encoding: .utf8)?
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                    .prefix(5)
                    .joined(separator: "\n") ?? ""

                NSLog("SingBoxManager: sing-box startup failed with exit code \(process.terminationStatus)")
                throw SingBoxError.startFailed(process.terminationStatus, stderrText)
            }

            // Process started successfully — now drain stderr too
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                _ = handle.availableData
            }
            return
        }

        try process.run()
        self.process = process

        NSLog("SingBoxManager: sing-box started (PID: \(process.processIdentifier))")

        // Wait briefly to check if it started successfully
        try await Task.sleep(for: .milliseconds(500))

        if !process.isRunning {
            NSLog("SingBoxManager: sing-box startup failed with exit code \(process.terminationStatus)")
            throw SingBoxError.startFailed(process.terminationStatus, "Check logs for details")
        }
    }

    private func handleTermination(exitCode: Int32) async {
        // Don't restart if we've hit the limit or explicitly stopped
        guard restartCount < maxRestarts else {
            NSLog("SingBoxManager: Max restart attempts reached, not restarting")
            return
        }

        // Don't restart on clean exit (0) or if we explicitly stopped
        guard exitCode != 0 else {
            NSLog("SingBoxManager: Clean exit, not restarting")
            return
        }

        restartCount += 1
        NSLog("SingBoxManager: Attempting restart \(restartCount)/\(maxRestarts) in \(restartDelay)s")

        // Wait before restarting
        try? await Task.sleep(for: .seconds(restartDelay))

        // Restart
        do {
            try await launchProcess()
            NSLog("SingBoxManager: Restart successful")
        } catch {
            NSLog("SingBoxManager: Restart failed: \(error)")
        }
    }
}

// MARK: - Errors

enum SingBoxError: LocalizedError {
    case binaryNotFound(String)
    case noConfig
    case notRunning
    case startFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case let .binaryNotFound(path):
            "sing-box binary not found at \(path)"
        case .noConfig:
            "No configuration provided"
        case .notRunning:
            "sing-box is not running"
        case let .startFailed(code, stderr):
            "sing-box failed to start (exit code: \(code))\(stderr.isEmpty ? "" : "\n\(stderr)")"
        }
    }
}
