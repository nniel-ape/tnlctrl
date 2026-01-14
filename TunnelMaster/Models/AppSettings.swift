//
//  AppSettings.swift
//  TunnelMaster
//
//  App-wide settings persisted to disk.
//

import Foundation

struct AppSettings: Codable, Equatable {
    var enableSingBoxLogs: Bool = false

    static let `default` = AppSettings()
}
