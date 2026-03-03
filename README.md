# tnl_ctrl

A macOS menu bar app for unified VPN and proxy management, powered by [sing-box](https://sing-box.sagernet.org/).

<!-- ![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6-orange) ![sing-box 1.13](https://img.shields.io/badge/sing--box-1.13-green) -->

## Overview

tnl_ctrl brings all your proxy and VPN configurations into a single native macOS app. Import configs from any major format, deploy new proxy servers with a guided wizard, and route traffic through sing-box with flexible split tunneling and multi-hop chaining — all from your menu bar.

## Features

- **7 protocols** — VLESS, VMess, Trojan, Shadowsocks, SOCKS5, WireGuard, Hysteria2
- **Universal config import** — sing-box JSON, Clash/Meta YAML, V2Ray/Xray JSON, and URI schemes (`ss://`, `trojan://`, `vmess://`, `vless://`, `hy2://`, `socks5://`)
- **Full & split tunneling** — Route all traffic or define granular rules by app, domain, IP range, or geolocation (GeoIP/GeoSite)
- **Multi-hop chaining** — Chain proxies sequentially for enhanced privacy (You → Proxy A → Proxy B → Target)
- **Server deployment wizard** — Deploy proxy containers to local Docker or remote servers via SSH with auto-generated secure configs
- **Latency testing** — Real TCP handshake probes to measure and display server response times
- **Secure credentials** — Passwords, keys, and UUIDs stored in macOS Keychain, never in plaintext
- **Config export/import** — Back up and share your full app configuration as `.tnlctrl` bundles
- **Routing presets** — Save and switch between tunnel configurations instantly
- **Rule organization** — Group, reorder (drag-and-drop), and manage routing rules with conflict detection

## Architecture

tnl_ctrl uses a three-process model:

```
┌─────────────────────────┐
│   Main App (sandboxed)  │  SwiftUI menu bar app
│   Config, UI, Docker    │  Settings window
└───────────┬─────────────┘
            │ XPC (NSXPCConnection)
┌───────────▼─────────────┐
│   Privileged Helper     │  Root daemon via SMAppService
│   nniel.tnlctrl    │  Manages sing-box lifecycle
│   .helper               │
└───────────┬─────────────┘
            │ Process management
┌───────────▼─────────────┐
│   sing-box              │  TUN interface (utun199)
│   Network tunneling     │  Full/split traffic routing
└─────────────────────────┘
```

## Requirements

- **macOS 15** (Sequoia) or later
- **Xcode 16+** (to build from source)
- **Docker** (optional) — Docker Desktop or colima, only needed for the deployment wizard

sing-box is bundled with the app — no separate installation required.

## Building from Source

```bash
git clone https://github.com/nniel/tnl_ctrl.git
cd tnl_ctrl
open tnl_ctrl.xcodeproj
```

Build and run the `tnl_ctrl` scheme in Xcode. The helper target builds automatically as a dependency.

For local development without a paid Apple Developer account, ad-hoc sign both targets:

```bash
codesign --deep --force --sign - build/Release/tnl_ctrl.app
```

## Usage

1. **Install the helper** — On first launch, tnl_ctrl prompts to install its privileged helper via macOS system dialog
2. **Add services** — Import existing configs (drag-and-drop files, paste text, or enter URIs) or deploy a new server with the wizard
3. **Configure routing** — Choose full tunnel or set up split tunnel rules in the Tunnel tab
4. **Connect** — Click the menu bar icon and toggle the connection

## Supported Protocols

| Protocol | Default Port | Notes |
|----------|:---:|-------|
| VLESS | 443 | Modern protocol with Reality support |
| VMess | 443 | V2Ray protocol |
| Trojan | 443 | TLS-based proxy |
| Shadowsocks | 8388 | Lightweight encrypted proxy |
| SOCKS5 | 1080 | Generic SOCKS proxy |
| WireGuard | 51820 | VPN protocol |
| Hysteria2 | 443 | UDP-based, high-performance |

## Project Structure

```
tnl_ctrl/
├── App/                    # App entry point, AppState, WindowManager
├── Models/                 # Service, Server, RoutingRule, TunnelConfig
├── Services/
│   ├── ConfigImporter/     # Parsers (sing-box, Clash, V2Ray, URI)
│   ├── Tunnel/             # SingBoxConfigBuilder, TunnelManager, LatencyTester
│   ├── XPC/                # XPCClient, XPCProtocol
│   └── ...                 # ServiceStore, KeychainManager, Docker, SSH
├── Views/
│   ├── MenuBar/            # Menu bar dropdown UI
│   ├── Settings/           # Services, Tunnel, General tabs
│   ├── ServiceForm/        # Protocol-specific editing forms
│   ├── Rules/              # Rule list, builder, inspector
│   └── Onboarding/         # First-launch wizard
└── Wizard/                 # Deployment wizard, protocol templates

tnl_ctrl_helper/         # Privileged helper daemon
├── main.swift              # XPC listener
├── SingBoxManager.swift    # sing-box process management
└── bin/                    # Bundled sing-box binary

tnl_ctrl_tests/          # Parser, builder, migration tests
```

## License

This project is open source. License details coming soon.
