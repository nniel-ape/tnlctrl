//
//  Service.swift
//  TunnelMaster
//

import Foundation

struct Service: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var `protocol`: ProxyProtocol
    var server: String
    var port: Int
    var credentialRef: String?
    var settings: [String: AnyCodableValue]
    var latency: Int?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        protocol: ProxyProtocol,
        server: String,
        port: Int? = nil,
        credentialRef: String? = nil,
        settings: [String: AnyCodableValue] = [:],
        latency: Int? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.protocol = `protocol`
        self.server = server
        self.port = port ?? `protocol`.defaultPort
        self.credentialRef = credentialRef
        self.settings = settings
        self.latency = latency
        self.isEnabled = isEnabled
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
