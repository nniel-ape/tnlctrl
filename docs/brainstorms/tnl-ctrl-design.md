# tnl_ctrl Design Document

## Overview

**tnl_ctrl** is a macOS 26 menu bar application for managing VPN and proxy services end-to-end. It solves two problems:

1. **Service fragmentation** — Users juggle multiple proxy configs from different sources (Clash, V2Ray, subscription links) with no unified management.
2. **Deployment complexity** — Setting up secure tunnel servers requires manual Docker/SSH work and protocol expertise.

tnl_ctrl provides a single app to import existing configs, deploy new servers via guided wizard, and route traffic through sing-box with flexible split tunneling and multi-hop chaining. Built for macOS 26 using SwiftUI, it runs as a menu bar app with a separate settings window, stores credentials securely in Keychain, and uses SMAppService for the privileged helper.

## Goals

- **Unified config management** — Import and normalize configs from sing-box JSON, Clash/Meta YAML, V2Ray/Xray JSON, and URI schemes (ss://, trojan://, vmess://, vless://, socks5://)
- **One-click server deployment** — Wizard-driven Docker container provisioning for local or remote servers via SSH, supporting VLESS+Reality, Trojan, VMess, Shadowsocks, WireGuard, Hysteria2, and SOCKS5
- **Full system tunneling** — Route all macOS traffic through sing-box privileged helper with TUN interface
- **Granular split tunneling** — Define routing rules by app (process name/path), domain/IP pattern, or geo-location (GeoIP/GeoSite databases)
- **Multi-hop chaining** — Chain proxies sequentially (You → Proxy1 → Proxy2 → Target) for enhanced privacy
- **Secure by default** — Store server credentials and keys in macOS Keychain, sandbox app data
- **Native macOS experience** — Menu bar app with quick toggle, settings window for configuration, SMAppService for privilege escalation

## Non-Goals

- **iOS/iPadOS support** — macOS only; no Catalyst or mobile builds
- **Built-in proxy server binaries** — We orchestrate Docker containers, not bundle protocol binaries in the app itself
- **Subscription URL auto-refresh** — Import is manual; no background polling of subscription endpoints
- **Traffic analytics/logging** — No packet inspection, bandwidth graphs, or connection logs beyond basic status
- **Protocol development** — We use existing protocols via sing-box; no custom protocol implementation
- **Windows/Linux clients** — Out of scope; this is a macOS-native app
- **Paid features or licensing** — Fully open source, no premium tiers

## User Experience

### Menu Bar
- SF Symbol icon shows tunnel status (disconnected / connecting / connected)
- Click reveals dropdown: quick connect toggle, active server name, latency indicator, and "Open Settings" button
- Right-click or Option-click opens context menu with recent servers

### Settings Window — Services Tab
- List of all imported/created services with status badges
- "Import" button: drag-drop files, paste config text, or enter subscription URL
- "Add Server" button: launches deployment wizard
- Each service row shows: name, protocol icon, server address, and actions (edit, delete, test latency)

### Settings Window — Tunnel Tab
- Toggle: Full Tunnel vs Split Tunnel mode
- Split rules editor:
  - App rules: select apps from list or browse for .app bundles
  - Domain rules: text field with wildcard support (*.google.com)
  - Geo rules: dropdown for country-based routing (uses GeoIP/GeoSite)
- Chain editor: drag-drop services to build sequential hop order

### Deployment Wizard (modal sheet)
1. Choose target: Local Docker or Remote Server (SSH key auth only)
2. Select protocol: pick from supported list, shows recommended defaults
3. Configure: auto-generates secure config (keys, ports), allows customization
4. Deploy: shows progress, tests connectivity, imports resulting client config

### First Launch
- Prompts to install privileged helper via SMAppService
- Brief onboarding explaining menu bar location and import options

## Technical Approach

### Architecture: Three-Process Model
1. **Main App** (sandboxed) — SwiftUI menu bar app, settings UI, config management, Docker orchestration
2. **Privileged Helper** (root) — Bundles sing-box binary, manages TUN interface, applies routing rules. Installed via SMAppService, communicates with main app over XPC
3. **Docker Engine** (external) — Local Docker Desktop/colima or remote Docker over SSH for server deployment

### Config Normalization
- All imported configs (Clash, V2Ray, URIs) are parsed and converted to sing-box JSON format internally
- Single source of truth: `~/Library/Application Support/tnl_ctrl/services/` stores normalized configs
- Credentials (private keys, passwords) stored separately in Keychain, referenced by service ID

### Privileged Helper Communication
- XPC Mach service registered via SMAppService (launchd plist embedded in helper bundle)
- Protocol: Codable structs over NSXPCConnection — commands: `startTunnel(config)`, `stopTunnel`, `getStatus`, `applyRules(rules)`
- Helper validates caller's code signature before accepting commands
- Auto-restart sing-box on crash with logging for diagnostics

### Split Tunneling Implementation (sing-box only, no Network Extension)
- sing-box TUN mode with `auto_route` for full tunneling
- App-based rules: sing-box's `process_name` and `process_path` route rules — matches traffic by originating process
- Domain/IP rules: sing-box's `domain`, `domain_suffix`, `domain_keyword`, `ip_cidr` rules
- Geo rules: sing-box's `geoip` and `geosite` rule types with bundled databases
- All routing logic lives in sing-box config; helper just applies the generated config

### Multi-Hop Chaining
- Implemented via sing-box's outbound chaining: each hop defined as outbound, final outbound chains through previous using `detour` field
- Config generator builds nested outbound structure from user's drag-drop order

### Docker Deployment
- Local: shell out to `docker` CLI (detect Docker Desktop or colima socket)
- Remote: SSH key authentication only (no password auth), tunnel to remote Docker socket or execute commands over SSH
- Container images: curated per-protocol images (e.g., `ghcr.io/tunnelmaster/vless-reality`) or user-specified

### Latency Testing
- Real TCP handshake probes to measure server latency
- Background periodic checks for active services
- Visual latency indicator in menu bar dropdown and services list

### No Paid Developer Account Required
- SMAppService + XPC works with free Developer ID (ad-hoc signing for local dev)
- No entitlements that require paid account (no Network Extension, no App Groups for App Store)
- Users can build from source with `codesign --deep --force --sign -` for local use

## Key Components

### Main App Bundle
- `tnl_ctrlApp.swift` — App entry point, menu bar setup via MenuBarExtra
- `MenuBarView.swift` — Dropdown UI with status, quick toggle, server list
- `SettingsWindow/` — SwiftUI views for Services, Tunnel, and General tabs
- `ConfigImporter/` — Parsers for each format (sing-box, Clash, V2Ray, URI schemes)
- `ConfigNormalizer.swift` — Converts all formats to unified sing-box JSON
- `DockerManager.swift` — Local/remote Docker CLI wrapper, container lifecycle
- `SSHClient.swift` — SSH key-based connection handling for remote deployments
- `KeychainManager.swift` — Secure credential storage and retrieval
- `XPCClient.swift` — NSXPCConnection wrapper for helper communication
- `ConfigExporter.swift` — Export configs (without secrets) for backup/sharing

### Privileged Helper Bundle (`com.tnlctrl.helper`)
- `main.swift` — XPC service listener, command dispatcher
- `SingBoxManager.swift` — Spawns/monitors sing-box process, handles config reloads, auto-restart on crash
- `ConfigBuilder.swift` — Generates sing-box JSON from normalized services + routing rules
- `CrashLogger.swift` — Logs helper/sing-box crashes for diagnostics
- Embedded sing-box binary — Universal binary (arm64 + x86_64) bundled in helper resources
- `GeoDatabase/` — Bundled geoip.db and geosite.db files

### Geo Database Updates
- Bundled databases included with app releases
- On-demand update button in settings
- Weekly automatic background check for newer versions from sing-geoip/sing-geosite releases

### Deployment Wizard
- `WizardView.swift` — Multi-step sheet UI
- `ProtocolTemplates/` — Per-protocol server config generators (VLESS, Trojan, etc.)
- `ContainerSpecs/` — Docker Compose / run command templates per protocol

### Shared Models (Swift package)
- `Service.swift` — Service definition (id, name, protocol, server, port, credentials ref)
- `RoutingRule.swift` — Rule types (app, domain, IP, geo) with match criteria
- `TunnelConfig.swift` — Full tunnel configuration (services, chains, rules)
- `XPCProtocol.swift` — Shared protocol definition for app ↔ helper communication

## Decisions Made

| Topic | Decision |
|-------|----------|
| sing-box updates | Bundle fixed version with app releases |
| GeoIP/GeoSite updates | On-demand button + weekly auto-check |
| Remote Docker auth | SSH key only (no password) |
| Config export | Supported (excludes secrets) |
| Latency testing | Real TCP probes |
| Menu bar icon | SF Symbols |
| Crash recovery | Auto-restart sing-box with logging |

## Open Questions

- **Localization** — English only initially, or plan for i18n from the start?

---
*Generated via /brainstorm on 2026-01-13*
