//
//  Service.swift
//  TunnelMaster
//

import Foundation

// MARK: - ServiceSource

enum ServiceSource: String, Codable, Hashable, Sendable {
    case imported
    case created
}

// MARK: - Service

struct Service: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var `protocol`: ProxyProtocol
    var server: String
    var port: Int
    var credentialRef: String?
    var settings: [String: AnyCodableValue]
    var latency: Int?
    var source: ServiceSource
    var serverId: UUID?
    var createdAt: Date

    // MARK: - CodingKeys for migration

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case `protocol`
        case server
        case port
        case credentialRef
        case settings
        case latency
        case source
        case serverId
        case createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        protocol: ProxyProtocol,
        server: String,
        port: Int? = nil,
        credentialRef: String? = nil,
        settings: [String: AnyCodableValue] = [:],
        latency: Int? = nil,
        source: ServiceSource = .imported,
        serverId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.protocol = `protocol`
        self.server = server
        self.port = port ?? `protocol`.defaultPort
        self.credentialRef = credentialRef
        self.settings = settings
        self.latency = latency
        self.source = source
        self.serverId = serverId
        self.createdAt = createdAt
    }

    // MARK: - Codable with migration support

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.protocol = try container.decode(ProxyProtocol.self, forKey: .protocol)
        self.server = try container.decode(String.self, forKey: .server)
        self.port = try container.decode(Int.self, forKey: .port)
        self.credentialRef = try container.decodeIfPresent(String.self, forKey: .credentialRef)
        self.settings = try container.decodeIfPresent([String: AnyCodableValue].self, forKey: .settings) ?? [:]
        self.latency = nil // Not persisted — measured at runtime

        // Migration: new fields with defaults
        self.source = try container.decodeIfPresent(ServiceSource.self, forKey: .source) ?? .imported
        self.serverId = try container.decodeIfPresent(UUID.self, forKey: .serverId)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(`protocol`, forKey: .protocol)
        try container.encode(server, forKey: .server)
        try container.encode(port, forKey: .port)
        try container.encodeIfPresent(credentialRef, forKey: .credentialRef)
        try container.encode(settings, forKey: .settings)
        // latency is ephemeral runtime state — not persisted
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(serverId, forKey: .serverId)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - AnyCodableValue for protocol-specific settings

enum AnyCodableValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .dictionary(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case let .int(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }
}
