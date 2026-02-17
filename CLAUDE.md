# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TunnelMaster is a macOS menu bar application for unified VPN/proxy management. It uses a **three-process architecture**:

1. **Main App** (TunnelMaster) — Sandboxed SwiftUI app for UI, config management, Docker orchestration
2. **Privileged Helper** (TunnelMasterHelper) — Root daemon via SMAppService for sing-box process management and network tunneling
3. **External Dependencies** — Docker Engine, sing-box binary, geo databases (geoip.db, geosite.db)

## Build & Test Commands

```fish
# Build main app (Debug)
xcodebuild -scheme TunnelMaster -configuration Debug build

# Build helper (Debug)
xcodebuild -scheme TunnelMasterHelper -configuration Debug build

# Build both for Release
xcodebuild -scheme TunnelMaster -configuration Release build

# Clean build
xcodebuild clean -scheme TunnelMaster

# Run all tests
xcodebuild test -scheme TunnelMaster -destination 'platform=macOS'

# Run a single test class
xcodebuild test -scheme TunnelMaster -destination 'platform=macOS' -only-testing:TunnelMasterTests/SingBoxConfigBuilderTests

# Run a single test method
xcodebuild test -scheme TunnelMaster -destination 'platform=macOS' -only-testing:TunnelMasterTests/SingBoxConfigBuilderTests/testBuildVLESSOutbound

# Verify sing-box config generation
sing-box check -c /path/to/config.json
```

### Test Structure

Tests live in `TunnelMasterTests/` with:
- `Parsers/` — Tests for all config importers (SingBox, Clash, V2Ray, URI)
- `Builder/` — `SingBoxConfigBuilderTests` — comprehensive protocol/transport/routing tests
- `Mocks/MockKeychainManager.swift` — Test double for KeychainManager
- `Fixtures/ConfigFixtures.swift` — Factory methods for test Service/TunnelConfig objects

Tests use `@MainActor` and `async` setUp/tearDown. `SingBoxConfigBuilder` tests use `MockKeychainManager` with `preloadCredential()` to inject credentials without touching the real Keychain.

## Architecture

### XPC Communication Flow

```
Main App (sandboxed)
    ↓ NSXPCConnection
XPCClient.swift → XPCProtocol.swift ← TunnelMasterHelper/main.swift
                                            ↓
                                    SingBoxManager.swift
                                            ↓
                                    sing-box process (TUN)
```

### Key Components

| Component | Location | Role |
|-----------|----------|------|
| AppState | `TunnelMaster/App/AppState.swift` | Central state container, orchestrates tunnel lifecycle |
| TunnelManager | `TunnelMaster/Services/Tunnel/TunnelManager.swift` | Tunnel start/stop, config building, status polling |
| XPCClient | `TunnelMaster/Services/XPC/XPCClient.swift` | Actor wrapping NSXPCConnection with async/await |
| SingBoxManager | `TunnelMasterHelper/SingBoxManager.swift` | Actor managing sing-box process (start/stop/SIGHUP reload) |
| SingBoxConfigBuilder | `TunnelMaster/Services/Tunnel/SingBoxConfigBuilder.swift` | Converts Service models → sing-box JSON |
| ConfigImporter/* | `TunnelMaster/Services/ConfigImporter/` | Parsers for sing-box, Clash, V2Ray, URI schemes |
| ServiceStore | `TunnelMaster/Services/ServiceStore.swift` | JSON persistence to ~/Library/Application Support/TunnelMaster/ |
| LatencyTester | `TunnelMaster/Services/Tunnel/LatencyTester.swift` | TCP connect latency using Network framework |
| Deployer | `TunnelMaster/Wizard/Deployer.swift` | Deploys proxy containers to local Docker or remote servers via SSH |

### Data Flow for Tunnel Start

1. User clicks Connect → `AppState.connect()`
2. `TunnelManager.startTunnel()` validates helper is installed
3. `SingBoxConfigBuilder.build()` generates sing-box JSON from services + rules
4. `XPCClient.startTunnel(configJSON:)` sends config to helper
5. Helper's `SingBoxManager.start()` writes config to temp file, spawns sing-box process
6. TunnelManager polls status every 5 seconds via XPC

### XPC Protocol (`XPCProtocol.swift`)

```swift
@objc public protocol HelperProtocol {
    func startTunnel(configJSON: String, reply: @escaping (Bool, String?) -> Void)
    func stopTunnel(reply: @escaping (Bool, String?) -> Void)
    func getStatus(reply: @escaping (String) -> Void)  // Returns TunnelStatus raw value
    func reloadConfig(configJSON: String, reply: @escaping (Bool, String?) -> Void)
    func getVersion(reply: @escaping (String) -> Void)
}
```

Service name: `nniel.TunnelMaster.helper`

### Concurrency Patterns

- **@MainActor @Observable:** `AppState`, `TunnelManager`, `HelperInstaller`, `LatencyTester`, `ServiceStore` — SwiftUI state and UI-bound singletons
- **Actors:** `XPCClient`, `SingBoxManager`, `KeychainManager` — thread-safe background singletons
- **Continuations:** XPC callbacks wrapped with `withCheckedThrowingContinuation` for async/await
- **Singletons pattern:** Most services use `static let shared` — accessed throughout via `.shared`

### Logging

Uses `OSLog` with subsystem `nniel.TunnelMaster`:
```swift
private let logger = Logger(subsystem: "nniel.TunnelMaster", category: "ComponentName")
```

### Data Persistence

`ServiceStore` saves/loads all app data as JSON files in `~/Library/Application Support/TunnelMaster/`:
- `services.json` — Array of Service
- `servers.json` — Array of Server
- `tunnel-config.json` — TunnelConfig (mode, rules, chain, presets)
- `settings.json` — AppSettings

### Codable Migration Pattern

All models use a defensive decoding pattern for backward compatibility. New fields use `decodeIfPresent` with sensible defaults so existing user data doesn't break:
```swift
self.newField = try container.decodeIfPresent(Type.self, forKey: .newField) ?? defaultValue
```
Follow this pattern when adding new fields to any persisted model.

### Credential Storage

Sensitive data (UUIDs, passwords, private keys) stored in Keychain via `KeychainManager`.
Services store only a `credentialRef` (UUID reference). `SingBoxConfigBuilder` retrieves actual credentials when generating configs.

## Domain Model

### Server vs Service

- **Server** — A physical or virtual machine (VPS, local Docker host). One server can host multiple services. Has a `deploymentTarget` of `.local` or `.remote`.
- **Service** — A proxy or VPN configuration (VLESS, VMess, Hysteria2, WireGuard, etc.). Has a `source` of `.imported` (from config file/URI) or `.created` (deployed via wizard).

### Relationships

```
Server (physical machine)
├── host, sshPort, sshUsername, sshKeyPath
├── deploymentTarget: .local | .remote
├── containerIds: ["tunnelmaster-1234"]
└── serviceIds: [uuid1, uuid2]

Service (proxy/VPN config)
├── name, protocol, server, port
├── settings: [String: AnyCodableValue]  // Protocol-specific
├── credentialRef: String?  // → Keychain lookup
├── source: .imported | .created
└── serverId: UUID?  // → Server.id
```

`AnyCodableValue` is a type-erased Codable enum (.string, .int, .bool, .double, .array, .dictionary, .null) used for protocol-specific settings.

## Supported Protocols

VLESS, VMess, Trojan, Shadowsocks, SOCKS5, WireGuard, Hysteria2

Each protocol has specific settings in `Service.settings: [String: AnyCodableValue]` and corresponding handling in `SingBoxConfigBuilder`. Protocol templates for deployment live in `Wizard/ProtocolTemplates/`.

## sing-box Config Generation

`SingBoxConfigBuilder.build()` generates:
- **DNS:** Cloudflare (via proxy), Google (direct), block
- **Inbounds:** TUN interface `utun199` with `auto_route`, `strict_route`
- **Outbounds:** Service selector, individual services, chain outbound, direct, block
- **Route:** Rules from `TunnelConfig`, final outbound based on mode (full/split)

Chaining uses sing-box's `detour` field for multi-hop.

## Helper Installation

Uses SMAppService (macOS 13+). The helper binary is embedded in the main app bundle at `Contents/Library/LaunchDaemons/`.

`HelperInstaller` manages registration/unregistration. The helper runs as a launchd daemon with root privileges.

## Dependencies

- **Yams** — YAML parsing for Clash configs
- **Security framework** — Keychain access (no external package)
- **ServiceManagement** — SMAppService for helper installation
- **Network framework** — TCP connect latency testing

## sing-box Binary

The helper expects sing-box at:
1. Bundled in helper's Resources
2. Fallback: Homebrew paths (`/opt/homebrew/bin/sing-box`, `/usr/local/bin/sing-box`)

Geo databases (geoip.db, geosite.db) stored alongside the binary.
