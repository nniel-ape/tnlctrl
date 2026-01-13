//
//  XPCProtocol.swift
//  TunnelMaster
//
//  Shared protocol for communication between main app and privileged helper.
//

import Foundation

// MARK: - Service Identifier

let helperMachServiceName = "nniel.TunnelMaster.helper"
let helperBundleIdentifier = "nniel.TunnelMaster.helper"

// MARK: - XPC Protocol

@objc public protocol HelperProtocol {
    /// Start the tunnel with the given sing-box configuration
    func startTunnel(configJSON: String, reply: @escaping (Bool, String?) -> Void)

    /// Stop the running tunnel
    func stopTunnel(reply: @escaping (Bool, String?) -> Void)

    /// Get current tunnel status
    func getStatus(reply: @escaping (Bool, Int32) -> Void)

    /// Update sing-box configuration without restarting
    func reloadConfig(configJSON: String, reply: @escaping (Bool, String?) -> Void)

    /// Get helper version info
    func getVersion(reply: @escaping (String) -> Void)
}

// MARK: - Status Codes

public enum TunnelStatus: Int32, Sendable {
    case stopped = 0
    case starting = 1
    case running = 2
    case stopping = 3
    case error = -1
}

// MARK: - XPC Interface Setup

public func createHelperInterface() -> NSXPCInterface {
    NSXPCInterface(with: HelperProtocol.self)
}
