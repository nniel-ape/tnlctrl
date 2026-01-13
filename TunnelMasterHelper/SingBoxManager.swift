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

        // Fallback to /usr/local/bin for development
        return URL(fileURLWithPath: "/usr/local/bin/sing-box")
    }

    private var configDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelMasterHelper", isDirectory: true)
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    var pid: Int32? {
        guard let process = process, process.isRunning else { return nil }
        return process.processIdentifier
    }

    // MARK: - Lifecycle

    func start(configJSON: String) async throws {
        // Stop existing process if running
        if isRunning {
            await stop()
        }

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
        guard let process = process else { return }

        NSLog("SingBoxManager: Stopping sing-box (PID: \(process.processIdentifier))")

        // Send SIGTERM for graceful shutdown
        process.terminate()

        // Wait briefly for graceful termination
        try? await Task.sleep(for: .milliseconds(500))

        // Force kill if still running
        if process.isRunning {
            process.interrupt()
        }

        self.process = nil
        restartCount = maxRestarts // Prevent auto-restart
    }

    func reload(configJSON: String) async throws {
        guard let configPath = configPath else {
            throw SingBoxError.notRunning
        }

        // Write new config
        try configJSON.write(to: configPath, atomically: true, encoding: .utf8)

        // Send SIGHUP to reload
        if let process = process, process.isRunning {
            kill(process.processIdentifier, SIGHUP)
            NSLog("SingBoxManager: Sent SIGHUP to sing-box for config reload")
        } else {
            // If not running, start fresh
            try await start(configJSON: configJSON)
        }
    }

    // MARK: - Process Management

    private func launchProcess() async throws {
        guard FileManager.default.fileExists(atPath: singBoxPath.path) else {
            throw SingBoxError.binaryNotFound(singBoxPath.path)
        }

        guard let configPath = configPath else {
            throw SingBoxError.noConfig
        }

        NSLog("SingBoxManager: Launching sing-box from \(singBoxPath.path)")

        let process = Process()
        process.executableURL = singBoxPath
        process.arguments = ["run", "-c", configPath.path]
        process.currentDirectoryURL = configDirectory

        // Capture output for logging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Set up termination handler for auto-restart
        process.terminationHandler = { [weak self] terminatedProcess in
            let exitCode = terminatedProcess.terminationStatus
            NSLog("SingBoxManager: sing-box exited with code \(exitCode)")

            Task { [weak self] in
                await self?.handleTermination(exitCode: exitCode)
            }
        }

        // Log output asynchronously
        Task {
            for try await line in outputPipe.fileHandleForReading.bytes.lines {
                NSLog("sing-box: \(line)")
            }
        }

        Task {
            for try await line in errorPipe.fileHandleForReading.bytes.lines {
                NSLog("sing-box [error]: \(line)")
            }
        }

        try process.run()
        self.process = process

        NSLog("SingBoxManager: sing-box started (PID: \(process.processIdentifier))")

        // Wait briefly to check if it started successfully
        try await Task.sleep(for: .milliseconds(500))

        if !process.isRunning {
            throw SingBoxError.startFailed(process.terminationStatus)
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
    case startFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            "sing-box binary not found at \(path)"
        case .noConfig:
            "No configuration provided"
        case .notRunning:
            "sing-box is not running"
        case .startFailed(let code):
            "sing-box failed to start (exit code: \(code))"
        }
    }
}
