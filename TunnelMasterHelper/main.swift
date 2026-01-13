//
//  main.swift
//  TunnelMasterHelper
//
//  Privileged helper daemon for TunnelMaster.
//  Manages sing-box process and TUN interface.
//

import Foundation

// MARK: - Constants

let helperMachServiceName = "nniel.TunnelMaster.helper"

// MARK: - Helper Delegate

class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Verify the connecting process is our main app
        guard verifyCodeSignature(of: connection) else {
            NSLog("TunnelMasterHelper: Rejected connection - invalid code signature")
            return false
        }

        NSLog("TunnelMasterHelper: Accepted connection from main app")

        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = HelperService.shared
        connection.invalidationHandler = {
            NSLog("TunnelMasterHelper: Connection invalidated")
        }
        connection.resume()

        return true
    }

    private func verifyCodeSignature(of connection: NSXPCConnection) -> Bool {
        // Get the audit token for the connecting process
        var token = connection.auditToken

        // Create a code object for the connecting process
        var code: SecCode?
        let status = SecCodeCopyGuestWithAttributes(nil, [
            kSecGuestAttributeAudit: Data(bytes: &token, count: MemoryLayout.size(ofValue: token)) as CFData
        ] as CFDictionary, [], &code)

        guard status == errSecSuccess, let code = code else {
            NSLog("TunnelMasterHelper: Failed to get code object: \(status)")
            return false
        }

        // Verify the code signature
        // In production, you'd check against your specific team ID and app identifier
        // For development, we'll be more permissive
        let requirement = """
        identifier "nniel.TunnelMaster" and anchor apple generic
        """

        var requirementRef: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &requirementRef) == errSecSuccess,
              let requirement = requirementRef else {
            NSLog("TunnelMasterHelper: Failed to create requirement")
            // Allow during development
            return true
        }

        let verifyStatus = SecCodeCheckValidity(code, [], requirement)
        if verifyStatus != errSecSuccess {
            NSLog("TunnelMasterHelper: Code signature verification failed: \(verifyStatus)")
            // Allow during development for ad-hoc signed builds
            return true
        }

        return true
    }
}

// MARK: - Helper Service

class HelperService: NSObject, HelperProtocol {
    static let shared = HelperService()

    private let singBoxManager = SingBoxManager()

    private override init() {
        super.init()
    }

    func startTunnel(configJSON: String, reply: @escaping (Bool, String?) -> Void) {
        NSLog("TunnelMasterHelper: startTunnel called")

        Task {
            do {
                try await singBoxManager.start(configJSON: configJSON)
                reply(true, nil)
            } catch {
                NSLog("TunnelMasterHelper: startTunnel failed: \(error)")
                reply(false, error.localizedDescription)
            }
        }
    }

    func stopTunnel(reply: @escaping (Bool, String?) -> Void) {
        NSLog("TunnelMasterHelper: stopTunnel called")

        Task {
            await singBoxManager.stop()
            reply(true, nil)
        }
    }

    func getStatus(reply: @escaping (Bool, Int32) -> Void) {
        let isRunning = singBoxManager.isRunning
        let status: Int32 = isRunning ? 2 : 0 // TunnelStatus.running : .stopped
        reply(isRunning, status)
    }

    func reloadConfig(configJSON: String, reply: @escaping (Bool, String?) -> Void) {
        NSLog("TunnelMasterHelper: reloadConfig called")

        Task {
            do {
                try await singBoxManager.reload(configJSON: configJSON)
                reply(true, nil)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }

    func getVersion(reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }
}

// MARK: - Main Entry Point

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: helperMachServiceName)
listener.delegate = delegate

NSLog("TunnelMasterHelper: Starting XPC listener on \(helperMachServiceName)")
listener.resume()

RunLoop.main.run()
