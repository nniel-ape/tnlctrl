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

@preconcurrency @objc
public protocol HelperProtocol {
    /// Start the tunnel with the given sing-box configuration
    /// - Parameters:
    ///   - configJSON: sing-box JSON configuration
    ///   - enableLogs: Whether to write sing-box output to log file (false = redirect to /dev/null)
    func startTunnel(configJSON: String, enableLogs: Bool, reply: @escaping (Bool, String?) -> Void)

    /// Stop the running tunnel
    func stopTunnel(reply: @escaping (Bool, String?) -> Void)

    /// Get current tunnel status
    func getStatus(reply: @escaping (Bool, Int32) -> Void)

    /// Update sing-box configuration without restarting
    func reloadConfig(configJSON: String, reply: @escaping (Bool, String?) -> Void)

    /// Get helper version info
    func getVersion(reply: @escaping (String) -> Void)
}

// MARK: - Tunnel Status

public enum TunnelStatus: Int32, Sendable {
    case stopped = 0
    case connecting = 1
    case running = 2
    case disconnecting = 3
    case error = 4

    public var displayName: String {
        switch self {
        case .stopped: "Disconnected"
        case .connecting: "Connecting..."
        case .running: "Connected"
        case .disconnecting: "Disconnecting..."
        case .error: "Error"
        }
    }

    public var isConnected: Bool {
        self == .running
    }

    public var systemImage: String {
        switch self {
        case .stopped: "network.slash"
        case .connecting, .disconnecting: "network.badge.shield.half.filled"
        case .running: "network"
        case .error: "exclamationmark.triangle"
        }
    }
}

// MARK: - XPC Interface Setup

public nonisolated func createHelperInterface() -> NSXPCInterface {
    NSXPCInterface(with: HelperProtocol.self)
}
