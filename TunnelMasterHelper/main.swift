//
//  main.swift
//  TunnelMasterHelper
//
//  Entry point for the privileged helper daemon.
//

import Foundation

// MARK: - Helper Service

final class HelperService: NSObject, HelperProtocol {
    private let singBoxManager = SingBoxManager()

    func startTunnel(configJSON: String, reply: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                try await singBoxManager.start(configJSON: configJSON)
                reply(true, nil)
            } catch {
                NSLog("HelperService: Failed to start tunnel: \(error)")
                reply(false, error.localizedDescription)
            }
        }
    }

    func stopTunnel(reply: @escaping (Bool, String?) -> Void) {
        Task {
            await singBoxManager.stop()
            reply(true, nil)
        }
    }

    func getStatus(reply: @escaping (Bool, Int32) -> Void) {
        Task {
            let isRunning = await singBoxManager.isRunning
            let status: TunnelStatus = isRunning ? .running : .stopped
            reply(isRunning, status.rawValue)
        }
    }

    func reloadConfig(configJSON: String, reply: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                try await singBoxManager.reload(configJSON: configJSON)
                reply(true, nil)
            } catch {
                NSLog("HelperService: Failed to reload config: \(error)")
                reply(false, error.localizedDescription)
            }
        }
    }

    func getVersion(reply: @escaping (String) -> Void) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        reply(version)
    }
}

// MARK: - XPC Listener Delegate

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    // Keep a single shared service instance
    private let service = HelperService()

    // Track active connections to prevent deallocation
    private var activeConnections = Set<NSXPCConnection>()
    private let lock = NSLock()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        NSLog("TunnelMasterHelper: New XPC connection from PID \(newConnection.processIdentifier)")

        // Validate connecting process
        // In production, add code signature validation here

        newConnection.exportedInterface = createHelperInterface()
        newConnection.exportedObject = service

        // Track connection
        lock.lock()
        activeConnections.insert(newConnection)
        lock.unlock()

        newConnection.invalidationHandler = { [weak self, weak newConnection] in
            NSLog("TunnelMasterHelper: Connection invalidated")
            if let conn = newConnection {
                self?.lock.lock()
                self?.activeConnections.remove(conn)
                self?.lock.unlock()
            }
        }

        newConnection.interruptionHandler = {
            NSLog("TunnelMasterHelper: Connection interrupted")
        }

        newConnection.resume()
        return true
    }
}

// MARK: - Entry Point

NSLog("TunnelMasterHelper: Starting...")

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: helperMachServiceName)
listener.delegate = delegate
listener.resume()

NSLog("TunnelMasterHelper: Listening on \(helperMachServiceName)")

RunLoop.main.run()
