//
//  Server.swift
//  TunnelMaster
//

import Foundation

// MARK: - ServerStatus

enum ServerStatus: String, Codable, Hashable, Sendable {
    case active
    case stopped
    case unknown
    case error
}

// MARK: - Server

struct Server: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var host: String
    var sshPort: Int
    var sshUsername: String
    var sshKeyPath: String?
    var containerIds: [String]
    var serviceIds: [UUID]
    var createdAt: Date
    var status: ServerStatus
    var deploymentTarget: DeploymentTarget

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        sshPort: Int = 22,
        sshUsername: String = "root",
        sshKeyPath: String? = nil,
        containerIds: [String] = [],
        serviceIds: [UUID] = [],
        createdAt: Date = Date(),
        status: ServerStatus = .unknown,
        deploymentTarget: DeploymentTarget = .remote
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.sshPort = sshPort
        self.sshUsername = sshUsername
        self.sshKeyPath = sshKeyPath
        self.containerIds = containerIds
        self.serviceIds = serviceIds
        self.createdAt = createdAt
        self.status = status
        self.deploymentTarget = deploymentTarget
    }
}
