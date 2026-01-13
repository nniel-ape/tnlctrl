//
//  V2RayParser.swift
//  TunnelMaster
//

import Foundation

struct V2RayParser: ConfigImporter {
    private let keychainManager: any KeychainManaging

    init(keychainManager: any KeychainManaging = KeychainManager.shared) {
        self.keychainManager = keychainManager
    }

    func canImport(data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        // V2Ray configs have outbounds array with specific structure
        if let outbounds = json["outbounds"] as? [[String: Any]],
           let first = outbounds.first,
           first["protocol"] != nil {
            return true
        }
        return false
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
            guard let protocolName = outbound["protocol"] as? String,
                  let proto = mapProtocol(protocolName) else { continue }

            let service = try await parseOutbound(outbound, protocol: proto)
            services.append(service)
        }

        return services
    }

    // MARK: - Protocol Mapping

    private func mapProtocol(_ name: String) -> ProxyProtocol? {
        switch name.lowercased() {
        case "vless": return .vless
        case "vmess": return .vmess
        case "trojan": return .trojan
        case "shadowsocks": return .shadowsocks
        case "socks": return .socks5
        case "wireguard": return .wireguard
        default: return nil
        }
    }

    // MARK: - Outbound Parsing

    private func parseOutbound(_ outbound: [String: Any], protocol proto: ProxyProtocol) async throws -> Service {
        let tag = outbound["tag"] as? String ?? proto.displayName
        let settings = outbound["settings"] as? [String: Any] ?? [:]
        let streamSettings = outbound["streamSettings"] as? [String: Any] ?? [:]

        // Extract server info
        var server = ""
        var port = proto.defaultPort
        var parsedSettings: [String: AnyCodableValue] = [:]
        var credentialRef: String?

        switch proto {
        case .vless:
            if let vnext = (settings["vnext"] as? [[String: Any]])?.first {
                server = vnext["address"] as? String ?? ""
                port = vnext["port"] as? Int ?? proto.defaultPort

                if let users = (vnext["users"] as? [[String: Any]])?.first {
                    if let uuid = users["id"] as? String {
                        credentialRef = try await storeCredential(uuid, for: tag)
                    }
                    if let flow = users["flow"] as? String {
                        parsedSettings["flow"] = .string(flow)
                    }
                    if let encryption = users["encryption"] as? String {
                        parsedSettings["encryption"] = .string(encryption)
                    }
                }
            }
            parsedSettings.merge(parseStreamSettings(streamSettings)) { _, new in new }

        case .vmess:
            if let vnext = (settings["vnext"] as? [[String: Any]])?.first {
                server = vnext["address"] as? String ?? ""
                port = vnext["port"] as? Int ?? proto.defaultPort

                if let users = (vnext["users"] as? [[String: Any]])?.first {
                    if let uuid = users["id"] as? String {
                        credentialRef = try await storeCredential(uuid, for: tag)
                    }
                    if let alterId = users["alterId"] as? Int {
                        parsedSettings["alter_id"] = .int(alterId)
                    }
                    if let security = users["security"] as? String {
                        parsedSettings["security"] = .string(security)
                    }
                }
            }
            parsedSettings.merge(parseStreamSettings(streamSettings)) { _, new in new }

        case .trojan:
            if let servers = (settings["servers"] as? [[String: Any]])?.first {
                server = servers["address"] as? String ?? ""
                port = servers["port"] as? Int ?? proto.defaultPort

                if let password = servers["password"] as? String {
                    credentialRef = try await storeCredential(password, for: tag)
                }
            }
            parsedSettings.merge(parseStreamSettings(streamSettings)) { _, new in new }

        case .shadowsocks:
            if let servers = (settings["servers"] as? [[String: Any]])?.first {
                server = servers["address"] as? String ?? ""
                port = servers["port"] as? Int ?? proto.defaultPort

                if let password = servers["password"] as? String {
                    credentialRef = try await storeCredential(password, for: tag)
                }
                if let method = servers["method"] as? String {
                    parsedSettings["method"] = .string(method)
                }
            }

        case .socks5:
            if let servers = (settings["servers"] as? [[String: Any]])?.first {
                server = servers["address"] as? String ?? ""
                port = servers["port"] as? Int ?? proto.defaultPort

                if let users = (servers["users"] as? [[String: Any]])?.first {
                    if let user = users["user"] as? String {
                        parsedSettings["username"] = .string(user)
                    }
                    if let pass = users["pass"] as? String {
                        credentialRef = try await storeCredential(pass, for: tag)
                    }
                }
            }

        case .wireguard:
            if let peers = (settings["peers"] as? [[String: Any]])?.first {
                server = peers["endpoint"] as? String ?? ""
                // Extract port from endpoint if present (format: host:port)
                if let colonIndex = server.lastIndex(of: ":") {
                    port = Int(String(server[server.index(after: colonIndex)...])) ?? proto.defaultPort
                    server = String(server[..<colonIndex])
                }
                if let publicKey = peers["publicKey"] as? String {
                    parsedSettings["peer_public_key"] = .string(publicKey)
                }
            }
            if let secretKey = settings["secretKey"] as? String {
                credentialRef = try await storeCredential(secretKey, for: tag)
            }
            if let reserved = settings["reserved"] as? [Int] {
                parsedSettings["reserved"] = .array(reserved.map { .int($0) })
            }

        case .hysteria2:
            // V2Ray doesn't natively support Hysteria2
            break
        }

        return Service(
            name: tag,
            protocol: proto,
            server: server,
            port: port,
            credentialRef: credentialRef,
            settings: parsedSettings
        )
    }

    // MARK: - Stream Settings

    private func parseStreamSettings(_ stream: [String: Any]) -> [String: AnyCodableValue] {
        var settings: [String: AnyCodableValue] = [:]

        // Network/Transport
        if let network = stream["network"] as? String {
            settings["transport_type"] = .string(network)
        }

        // TLS
        if let security = stream["security"] as? String {
            settings["tls_enabled"] = .bool(security == "tls" || security == "xtls" || security == "reality")

            if security == "reality", let realitySettings = stream["realitySettings"] as? [String: Any] {
                settings["reality_enabled"] = .bool(true)
                if let publicKey = realitySettings["publicKey"] as? String {
                    settings["reality_public_key"] = .string(publicKey)
                }
                if let shortId = realitySettings["shortId"] as? String {
                    settings["reality_short_id"] = .string(shortId)
                }
                if let serverName = realitySettings["serverName"] as? String {
                    settings["tls_server_name"] = .string(serverName)
                }
            }
        }

        if let tlsSettings = stream["tlsSettings"] as? [String: Any] {
            if let serverName = tlsSettings["serverName"] as? String {
                settings["tls_server_name"] = .string(serverName)
            }
            if let allowInsecure = tlsSettings["allowInsecure"] as? Bool {
                settings["tls_insecure"] = .bool(allowInsecure)
            }
            if let alpn = tlsSettings["alpn"] as? [String] {
                settings["tls_alpn"] = .array(alpn.map { .string($0) })
            }
        }

        // WebSocket
        if let wsSettings = stream["wsSettings"] as? [String: Any] {
            if let path = wsSettings["path"] as? String {
                settings["transport_path"] = .string(path)
            }
            if let headers = wsSettings["headers"] as? [String: String],
               let host = headers["Host"] {
                settings["transport_host"] = .string(host)
            }
        }

        // gRPC
        if let grpcSettings = stream["grpcSettings"] as? [String: Any] {
            if let serviceName = grpcSettings["serviceName"] as? String {
                settings["transport_service_name"] = .string(serviceName)
            }
        }

        // HTTP/2
        if let httpSettings = stream["httpSettings"] as? [String: Any] {
            if let path = httpSettings["path"] as? String {
                settings["transport_path"] = .string(path)
            }
            if let host = (httpSettings["host"] as? [String])?.first {
                settings["transport_host"] = .string(host)
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
