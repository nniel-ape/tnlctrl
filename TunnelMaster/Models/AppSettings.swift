//
//  AppSettings.swift
//  TunnelMaster
//
//  App-wide settings persisted to disk.
//

import Foundation

enum CertificateStore: String, Codable, CaseIterable {
    case system
    case chrome
    case mozilla
}

struct AppSettings: Codable, Equatable {
    var enableSingBoxLogs = false
    var certificateStore: CertificateStore = .system

    static let `default` = AppSettings()

    init(enableSingBoxLogs: Bool = false, certificateStore: CertificateStore = .system) {
        self.enableSingBoxLogs = enableSingBoxLogs
        self.certificateStore = certificateStore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enableSingBoxLogs = try container.decodeIfPresent(Bool.self, forKey: .enableSingBoxLogs) ?? false
        self.certificateStore = try container.decodeIfPresent(CertificateStore.self, forKey: .certificateStore) ?? .system
    }
}
