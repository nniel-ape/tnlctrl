//
//  ConfigBundle.swift
//  tnl_ctrl
//
//  Encapsulates the entire app configuration for export/import.
//

import Foundation

struct ConfigBundle: Codable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let appVersion: String
    var services: [Service]
    var servers: [Server]
    var tunnelConfig: TunnelConfig
    var settings: AppSettings
    var presets: [TunnelPreset]
    var credentials: [String: String]
}
