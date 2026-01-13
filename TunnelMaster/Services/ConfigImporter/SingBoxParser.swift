//
//  SingBoxParser.swift
//  TunnelMaster
//

import Foundation

struct SingBoxParser: ConfigImporter {
    private let keychainManager: any KeychainManaging

    nonisolated init(keychainManager: any KeychainManaging) {
        self.keychainManager = keychainManager
    }

    func canImport(data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        // sing-box configs have outbounds array
        return json["outbounds"] != nil
    }

    func parse(data: Data) async throws -> [Service] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigImportError.invalidFormat("Not valid JSON")
        }

        guard let outbounds = json["outbounds"] as? [[String: Any]] else {
            throw ConfigImportError.missingRequiredField("outbounds")
        }

        var services: [Service] = []

        for outbound in outbounds {
            guard let type = outbound["type"] as? String else { continue }

            // Skip non-proxy outbounds
            guard let proxyProtocol = mapProtocol(type) else { continue }

            let service = try await parseOutbound(outbound, protocol: proxyProtocol)
            services.append(service)
        }

        return services
    }

    // MARK: - Protocol Mapping

    private func mapProtocol(_ type: String) -> ProxyProtocol? {
        switch type.lowercased() {
        case "vless": return .vless
        case "vmess": return .vmess
        case "trojan": return .trojan
        case "shadowsocks", "ss": return .shadowsocks
        case "socks", "socks5": return .socks5
        case "wireguard": return .wireguard
        case "hysteria2": return .hysteria2
        default: return nil
        }
    }

    // MARK: - Outbound Parsing

    private func parseOutbound(_ outbound: [String: Any], protocol proto: ProxyProtocol) async throws -> Service {
        let tag = outbound["tag"] as? String ?? proto.displayName
        let server = outbound["server"] as? String ?? ""
        let port = outbound["server_port"] as? Int ?? proto.defaultPort

        // Build settings dictionary
        var settings: [String: AnyCodableValue] = [:]

        // Store credential and get ref
        var credentialRef: String?

        switch proto {
        case .vless:
            if let uuid = outbound["uuid"] as? String {
                credentialRef = try await storeCredential(uuid, for: tag)
            }
            settings.merge(parseVLESSSettings(outbound)) { _, new in new }

        case .vmess:
            if let uuid = outbound["uuid"] as? String {
                credentialRef = try await storeCredential(uuid, for: tag)
            }
            if let alterId = outbound["alter_id"] as? Int {
                settings["alter_id"] = .int(alterId)
            }
            if let security = outbound["security"] as? String {
                settings["security"] = .string(security)
            }
            settings.merge(parseTransportSettings(outbound)) { _, new in new }

        case .trojan:
            if let password = outbound["password"] as? String {
                credentialRef = try await storeCredential(password, for: tag)
            }
            settings.merge(parseTLSSettings(outbound)) { _, new in new }

        case .shadowsocks:
            if let password = outbound["password"] as? String {
                credentialRef = try await storeCredential(password, for: tag)
            }
            if let method = outbound["method"] as? String {
                settings["method"] = .string(method)
            }

        case .socks5:
            if let username = outbound["username"] as? String {
                settings["username"] = .string(username)
            }
            if let password = outbound["password"] as? String {
                credentialRef = try await storeCredential(password, for: tag)
            }

        case .wireguard:
            if let privateKey = outbound["private_key"] as? String {
                credentialRef = try await storeCredential(privateKey, for: tag)
            }
            if let publicKey = outbound["peer_public_key"] as? String {
                settings["peer_public_key"] = .string(publicKey)
            }
            if let reserved = outbound["reserved"] as? [Int] {
                settings["reserved"] = .array(reserved.map { .int($0) })
            }

        case .hysteria2:
            if let password = outbound["password"] as? String {
                credentialRef = try await storeCredential(password, for: tag)
            }
            if let obfs = outbound["obfs"] as? [String: Any] {
                if let obfsType = obfs["type"] as? String {
                    settings["obfs_type"] = .string(obfsType)
                }
                if let obfsPassword = obfs["password"] as? String {
                    settings["obfs_password"] = .string(obfsPassword)
                }
            }
            settings.merge(parseTLSSettings(outbound)) { _, new in new }
        }

        return Service(
            name: tag,
            protocol: proto,
            server: server,
            port: port,
            credentialRef: credentialRef,
            settings: settings
        )
    }

    // MARK: - Settings Parsers

    private func parseVLESSSettings(_ outbound: [String: Any]) -> [String: AnyCodableValue] {
        var settings: [String: AnyCodableValue] = [:]

        if let flow = outbound["flow"] as? String {
            settings["flow"] = .string(flow)
        }

        settings.merge(parseTLSSettings(outbound)) { _, new in new }
        settings.merge(parseTransportSettings(outbound)) { _, new in new }
        settings.merge(parseRealitySettings(outbound)) { _, new in new }

        return settings
    }

    private func parseTLSSettings(_ outbound: [String: Any]) -> [String: AnyCodableValue] {
        var settings: [String: AnyCodableValue] = [:]

        if let tls = outbound["tls"] as? [String: Any] {
            settings["tls_enabled"] = .bool(tls["enabled"] as? Bool ?? false)

            if let serverName = tls["server_name"] as? String {
                settings["tls_server_name"] = .string(serverName)
            }
            if let insecure = tls["insecure"] as? Bool {
                settings["tls_insecure"] = .bool(insecure)
            }
            if let alpn = tls["alpn"] as? [String] {
                settings["tls_alpn"] = .array(alpn.map { .string($0) })
            }
        }

        return settings
    }

    private func parseTransportSettings(_ outbound: [String: Any]) -> [String: AnyCodableValue] {
        var settings: [String: AnyCodableValue] = [:]

        if let transport = outbound["transport"] as? [String: Any] {
            if let type = transport["type"] as? String {
                settings["transport_type"] = .string(type)
            }
            if let path = transport["path"] as? String {
                settings["transport_path"] = .string(path)
            }
            if let host = transport["host"] as? String {
                settings["transport_host"] = .string(host)
            }
            if let headers = transport["headers"] as? [String: String] {
                var headersDict: [String: AnyCodableValue] = [:]
                for (key, value) in headers {
                    headersDict[key] = .string(value)
                }
                settings["transport_headers"] = .dictionary(headersDict)
            }
        }

        return settings
    }

    private func parseRealitySettings(_ outbound: [String: Any]) -> [String: AnyCodableValue] {
        var settings: [String: AnyCodableValue] = [:]

        if let tls = outbound["tls"] as? [String: Any],
           let reality = tls["reality"] as? [String: Any] {
            settings["reality_enabled"] = .bool(reality["enabled"] as? Bool ?? false)

            if let publicKey = reality["public_key"] as? String {
                settings["reality_public_key"] = .string(publicKey)
            }
            if let shortId = reality["short_id"] as? String {
                settings["reality_short_id"] = .string(shortId)
            }
        }

        return settings
    }

    // MARK: - Credential Storage

    private func storeCredential(_ value: String, for tag: String) async throws -> String {
        let ref = await keychainManager.generateCredentialRef()
        try await keychainManager.save(value, for: ref)
        return ref
    }
}
