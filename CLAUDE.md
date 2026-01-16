# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TunnelMaster is a macOS menu bar application for unified VPN/proxy management. It uses a **three-process architecture**:

1. **Main App** (TunnelMaster) — Sandboxed SwiftUI app for UI, config management, Docker orchestration
2. **Privileged Helper** (TunnelMasterHelper) — Root daemon via SMAppService for sing-box process management and network tunneling
3. **External Dependencies** — Docker Engine, sing-box binary, geo databases (geoip.db, geosite.db)

## Build Commands

```fish
# Build main app (Debug)
xcodebuild -scheme TunnelMaster -configuration Debug build

# Build helper (Debug)
xcodebuild -scheme TunnelMasterHelper -configuration Debug build

# Build both for Release
xcodebuild -scheme TunnelMaster -configuration Release build

# Clean build
xcodebuild clean -scheme TunnelMaster

# Verify sing-box config generation
sing-box check -c /path/to/config.json
```

**Note:** There are no unit tests yet. Use `go test` pattern is not applicable — this is a Swift/Xcode project.

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

- **Actors:** `XPCClient`, `SingBoxManager`, `ServiceStore`, `KeychainManager` — thread-safe singletons
- **@Observable:** `AppState`, `TunnelManager`, `HelperInstaller` — SwiftUI state management
- **Continuations:** XPC callbacks wrapped with `withCheckedThrowingContinuation` for async/await

### Credential Storage

Sensitive data (UUIDs, passwords, private keys) stored in Keychain via `KeychainManager`.
Services store only a `credentialRef` (UUID reference). `SingBoxConfigBuilder` retrieves actual credentials when generating configs.

## Domain Model

### Server vs Service

- **Server** — A physical or virtual machine that can run Docker containers (VPS, local Docker host). Named by its address/hostname by default. One server can host multiple services.
- **Service** — A proxy or VPN configuration (VLESS, VMess, Hysteria2, WireGuard, etc.). Each service runs in a Docker container on a server. Has a user-friendly name like "Work VPN" or "US Proxy".

### Relationships

```
Server (physical machine)
├── host: "192.168.1.100" or "my-vps.example.com"
├── name: defaults to host address
├── containerIds: ["tunnelmaster-1234", "tunnelmaster-5678"]
└── serviceIds: [uuid1, uuid2]

Service (proxy/VPN config)
├── name: "Work VPN", "US VLESS", etc.
├── protocol: .vless, .hysteria2, .wireguard, etc.
├── server: host address
├── port: 443
└── serverId: -> Server.id (if deployed via wizard)
```

## Code Organization

```
TunnelMaster/
├── App/AppState.swift              # Global state, tunnel control
├── Models/                         # Service, RoutingRule, TunnelConfig, ProxyProtocol
├── Views/
│   ├── MenuBar/MenuBarView.swift   # Dropdown: status, services, actions
│   └── Settings/                   # SettingsWindow, ServicesTab, TunnelTab, GeneralTab
├── Services/
│   ├── ConfigImporter/             # SingBoxParser, ClashParser, V2RayParser, URIParser
│   ├── Tunnel/                     # TunnelManager, SingBoxConfigBuilder
│   ├── XPC/                        # XPCClient, XPCProtocol, HelperInstaller
│   ├── Docker/DockerManager.swift  # Container lifecycle
│   └── SSH/SSHClient.swift         # Remote command execution
└── Wizard/                         # Server deployment wizard

TunnelMasterHelper/
├── main.swift                      # XPC listener entry point
├── SingBoxManager.swift            # sing-box process lifecycle
└── nniel.TunnelMaster.helper.plist # launchd config
```

## Supported Protocols

VLESS, VMess, Trojan, Shadowsocks, SOCKS5, WireGuard, Hysteria2

Each protocol has specific settings in `Service.settings: [String: AnyCodableValue]` and corresponding handling in `SingBoxConfigBuilder`.

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

## sing-box Binary

The helper expects sing-box at:
1. Bundled in helper's Resources
2. Fallback: Homebrew paths (`/opt/homebrew/bin/sing-box`, `/usr/local/bin/sing-box`)

Geo databases (geoip.db, geosite.db) stored alongside the binary.
