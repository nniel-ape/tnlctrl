# tnl_ctrl Implementation Plan

## 1. Overview

Build a macOS 26 menu bar app for unified VPN/proxy management with two core modules: (1) service management with config import and Docker-based server deployment, and (2) tunnel setup using sing-box as a privileged helper for full/split tunneling and multi-hop chaining.

**Design doc:** `docs/brainstorms/tunnelmaster-design.md`

## 2. Prerequisites

### Required Tools
- **Xcode 26.2+** — macOS 26 SDK, Swift 6
- **Homebrew** — Package manager for dependencies
- **Docker Desktop or colima** — For local container testing
- **sing-box 1.10+** — Download universal binary from [GitHub releases](https://github.com/SagerNet/sing-box/releases)

### Environment Setup
```fish
# Install Homebrew if missing
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install colima (lightweight Docker alternative)
brew install colima docker
colima start

# Download sing-box universal binary
curl -L -o /tmp/sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/download/v1.10.0/sing-box-1.10.0-darwin-universal.tar.gz"
tar -xzf /tmp/sing-box.tar.gz -C /tmp
# Binary at /tmp/sing-box-1.10.0-darwin-universal/sing-box

# Download geo databases
curl -L -o /tmp/geoip.db "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db"
curl -L -o /tmp/geosite.db "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db"
```

### Swift Packages (add via Xcode)
- **Yams** — YAML parsing for Clash configs
- **SwiftNIO SSH** — SSH client for remote deployments
- **KeychainAccess** — Simplified Keychain wrapper

## 3. Codebase Orientation

### Current State
- Fresh Xcode project with default SwiftUI template
- Single target: `tnl_ctrl` (macOS app)
- Bundle ID: `nniel.tnlctrl`
- Deployment target: macOS 26.2

### Target Architecture
```
tnl_ctrl/
├── App/
│   ├── tnl_ctrlApp.swift      # Menu bar app entry
│   └── AppState.swift             # Global state container
├── Views/
│   ├── MenuBar/
│   │   └── MenuBarView.swift      # Dropdown UI
│   └── Settings/
│       ├── SettingsWindow.swift   # Tab container
│       ├── ServicesTab.swift      # Service list
│       ├── TunnelTab.swift        # Routing rules
│       └── GeneralTab.swift       # Preferences
├── Models/
│   ├── Service.swift              # Proxy/VPN service
│   ├── RoutingRule.swift          # Split tunnel rules
│   └── TunnelConfig.swift         # Full config
├── Services/
│   ├── ConfigImporter/            # Format parsers
│   ├── ConfigNormalizer.swift     # → sing-box JSON
│   ├── KeychainManager.swift      # Credential storage
│   ├── DockerManager.swift        # Container lifecycle
│   ├── SSHClient.swift            # Remote connections
│   └── XPCClient.swift            # Helper communication
├── Wizard/
│   ├── WizardView.swift           # Deployment wizard
│   └── ProtocolTemplates/         # Server configs
└── Resources/
    └── Assets.xcassets

tnl_ctrl_helper/                 # Separate target
├── main.swift                     # XPC listener
├── SingBoxManager.swift           # Process management
├── ConfigBuilder.swift            # Config generation
└── Resources/
    ├── sing-box                   # Embedded binary
    ├── geoip.db
    └── geosite.db

Shared/                            # Swift package
├── XPCProtocol.swift              # App ↔ Helper protocol
└── Models/                        # Shared types
```

## 4. Implementation Tasks

---

### Phase 1: Foundation (Tasks 1-5)

---

### Task 1: Convert to Menu Bar App

**Goal:** Transform the default window app into a menu bar app with MenuBarExtra.

**Files to touch:**
- `tnl_ctrl/tnl_ctrlApp.swift` — Replace WindowGroup with MenuBarExtra
- `tnl_ctrl/App/AppState.swift` — Create (new file)
- `tnl_ctrl/Views/MenuBar/MenuBarView.swift` — Create (new file)

**Implementation steps:**
1. Create `App/` and `Views/MenuBar/` directories in Xcode
2. Create `AppState.swift` with observable state:
   ```swift
   @Observable
   final class AppState {
       var isConnected = false
       var isConnecting = false
       var activeService: Service?
       var services: [Service] = []
   }
   ```
3. Create `MenuBarView.swift` with basic dropdown:
   - Status indicator (SF Symbol: `network.slash` / `network`)
   - Connect/Disconnect toggle
   - "Open Settings..." button
   - "Quit" button
4. Update `tnl_ctrlApp.swift`:
   ```swift
   @main
   struct tnl_ctrlApp: App {
       @State private var appState = AppState()

       var body: some Scene {
           MenuBarExtra {
               MenuBarView()
                   .environment(appState)
           } label: {
               Image(systemName: appState.isConnected ? "network" : "network.slash")
           }

           Settings {
               SettingsWindow()
                   .environment(appState)
           }
       }
   }
   ```
5. Delete `ContentView.swift` (no longer needed)

**Testing:**
- Build and run — app should appear only in menu bar
- Click menu bar icon — dropdown should appear
- Verify SF Symbol changes don't crash (state toggle)

**Verification:**
- App icon appears in menu bar (not Dock)
- Dropdown shows status and buttons
- Settings window opens via menu item

**Commit:** `feat: convert to menu bar app with MenuBarExtra`

---

### Task 2: Create Core Data Models

**Goal:** Define the data structures for services, routing rules, and configs.

**Files to touch:**
- `tnl_ctrl/Models/Service.swift` — Create
- `tnl_ctrl/Models/RoutingRule.swift` — Create
- `tnl_ctrl/Models/TunnelConfig.swift` — Create
- `tnl_ctrl/Models/Protocol.swift` — Create (enum for proxy protocols)

**Implementation steps:**
1. Create `Models/` directory
2. Create `Protocol.swift`:
   ```swift
   enum ProxyProtocol: String, Codable, CaseIterable {
       case vless, vmess, trojan, shadowsocks, socks5, wireguard, hysteria2

       var displayName: String { ... }
       var defaultPort: Int { ... }
   }
   ```
3. Create `Service.swift`:
   ```swift
   struct Service: Identifiable, Codable {
       let id: UUID
       var name: String
       var `protocol`: ProxyProtocol
       var server: String
       var port: Int
       var credentialRef: String?  // Keychain reference
       var settings: [String: AnyCodable]  // Protocol-specific
       var latency: Int?  // ms, nil = untested
       var isEnabled: Bool
   }
   ```
4. Create `RoutingRule.swift`:
   ```swift
   enum RuleType: String, Codable {
       case processName, processPath
       case domain, domainSuffix, domainKeyword
       case ipCidr
       case geoip, geosite
   }

   struct RoutingRule: Identifiable, Codable {
       let id: UUID
       var type: RuleType
       var value: String  // e.g., "Safari", "*.google.com", "US"
       var outbound: RuleOutbound  // direct, proxy, block
   }

   enum RuleOutbound: String, Codable {
       case direct, proxy, block
   }
   ```
5. Create `TunnelConfig.swift`:
   ```swift
   struct TunnelConfig: Codable {
       var mode: TunnelMode
       var rules: [RoutingRule]
       var chain: [UUID]  // Service IDs in order
   }

   enum TunnelMode: String, Codable {
       case full, split
   }
   ```

**Testing:**
- Write unit tests in `tnl_ctrl_tests/`:
  - Test JSON encoding/decoding round-trip for each model
  - Test default values

**Verification:**
- Models compile without errors
- JSON serialization works correctly
- Enums have all required cases

**Commit:** `feat: add core data models for services and routing rules`

---

### Task 3: Implement Keychain Manager

**Goal:** Securely store and retrieve credentials (passwords, private keys, UUIDs).

**Files to touch:**
- `tnl_ctrl/Services/KeychainManager.swift` — Create

**Implementation steps:**
1. Add KeychainAccess package via Xcode: File → Add Package Dependencies
   - URL: `https://github.com/kishikawakatsumi/KeychainAccess`
2. Create `Services/` directory
3. Create `KeychainManager.swift`:
   ```swift
   import KeychainAccess

   actor KeychainManager {
       static let shared = KeychainManager()
       private let keychain = Keychain(service: "nniel.tnlctrl")
           .accessibility(.afterFirstUnlock)

       func save(_ value: String, for key: String) throws { ... }
       func get(_ key: String) throws -> String? { ... }
       func delete(_ key: String) throws { ... }
       func generateCredentialRef() -> String { UUID().uuidString }
   }
   ```
4. Add entitlement for Keychain access in target settings (should be automatic with sandbox)

**Testing:**
- Unit test: save → get → verify value matches
- Unit test: delete → get → verify nil
- Unit test: get non-existent key → nil (no throw)

**Verification:**
- Credentials persist across app launches
- Keychain Access.app shows entries under "nniel.tnlctrl"

**Commit:** `feat: add KeychainManager for secure credential storage`

---

### Task 4: Implement Service Persistence

**Goal:** Save and load services from disk (Application Support directory).

**Files to touch:**
- `tnl_ctrl/Services/ServiceStore.swift` — Create
- `tnl_ctrl/App/AppState.swift` — Add persistence integration

**Implementation steps:**
1. Create `ServiceStore.swift`:
   ```swift
   actor ServiceStore {
       static let shared = ServiceStore()

       private var servicesURL: URL {
           FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
               .appendingPathComponent("tnl_ctrl/services.json")
       }

       func load() async throws -> [Service] { ... }
       func save(_ services: [Service]) async throws { ... }
   }
   ```
2. Create directory if needed on first save
3. Use JSONEncoder with `.prettyPrinted` for debugging
4. Update `AppState` to load on init and save on changes:
   ```swift
   @Observable
   final class AppState {
       var services: [Service] = [] {
           didSet { Task { try? await ServiceStore.shared.save(services) } }
       }

       func loadServices() async {
           services = (try? await ServiceStore.shared.load()) ?? []
       }
   }
   ```

**Testing:**
- Unit test: save services → load → verify equality
- Unit test: load from empty/missing file → empty array
- Unit test: corrupt JSON → graceful error

**Verification:**
- Check `~/Library/Application Support/tnl_ctrl/services.json` exists after adding a service
- Services persist after app restart

**Commit:** `feat: add ServiceStore for persistent service storage`

---

### Task 5: Build Settings Window Shell

**Goal:** Create the settings window with tab navigation (Services, Tunnel, General).

**Files to touch:**
- `tnl_ctrl/Views/Settings/SettingsWindow.swift` — Create
- `tnl_ctrl/Views/Settings/ServicesTab.swift` — Create (placeholder)
- `tnl_ctrl/Views/Settings/TunnelTab.swift` — Create (placeholder)
- `tnl_ctrl/Views/Settings/GeneralTab.swift` — Create (placeholder)

**Implementation steps:**
1. Create `Views/Settings/` directory
2. Create `SettingsWindow.swift`:
   ```swift
   struct SettingsWindow: View {
       var body: some View {
           TabView {
               ServicesTab()
                   .tabItem { Label("Services", systemImage: "server.rack") }
               TunnelTab()
                   .tabItem { Label("Tunnel", systemImage: "arrow.triangle.branch") }
               GeneralTab()
                   .tabItem { Label("General", systemImage: "gear") }
           }
           .frame(width: 600, height: 400)
       }
   }
   ```
3. Create placeholder views for each tab with "Coming soon" text
4. Verify Settings window opens from menu bar

**Testing:**
- Visual: tabs switch correctly
- Visual: window has correct size
- Visual: icons display properly

**Verification:**
- Settings menu item opens window
- All three tabs accessible
- Window is appropriately sized

**Commit:** `feat: add settings window with tab navigation`

---

### Phase 2: Config Import (Tasks 6-10)

---

### Task 6: Implement sing-box Config Parser

**Goal:** Parse native sing-box JSON configs into Service models.

**Files to touch:**
- `tnl_ctrl/Services/ConfigImporter/SingBoxParser.swift` — Create
- `tnl_ctrl/Services/ConfigImporter/ConfigImporter.swift` — Create (protocol)

**Implementation steps:**
1. Create `Services/ConfigImporter/` directory
2. Define `ConfigImporter.swift` protocol:
   ```swift
   protocol ConfigImporter {
       func canImport(data: Data) -> Bool
       func parse(data: Data) throws -> [Service]
   }
   ```
3. Create `SingBoxParser.swift`:
   - Parse `outbounds` array from sing-box JSON
   - Map each outbound to a `Service`
   - Extract credentials, store in Keychain via `KeychainManager`
   - Support types: `vless`, `vmess`, `trojan`, `shadowsocks`, `socks`, `wireguard`, `hysteria2`
4. Handle nested settings (TLS, transport, reality, etc.) via `settings: [String: AnyCodable]`

**Testing:**
- Unit test with sample sing-box configs for each protocol
- Test malformed JSON → appropriate error
- Test config with multiple outbounds → multiple services

**Verification:**
- Parse real sing-box config file
- Services appear in list with correct names/protocols

**Commit:** `feat: add sing-box JSON config parser`

---

### Task 7: Implement Clash/Meta Config Parser

**Goal:** Parse Clash YAML configs into Service models.

**Files to touch:**
- `tnl_ctrl/Services/ConfigImporter/ClashParser.swift` — Create

**Implementation steps:**
1. Add Yams package: `https://github.com/jpsim/Yams`
2. Create `ClashParser.swift`:
   - Parse YAML using Yams
   - Extract `proxies` array
   - Map Clash proxy types to `ProxyProtocol`:
     - `ss` → `.shadowsocks`
     - `vmess` → `.vmess`
     - `trojan` → `.trojan`
     - `vless` → `.vless`
     - `socks5` → `.socks5`
     - `hysteria2` → `.hysteria2`
   - Convert Clash-specific fields to sing-box equivalents in `settings`

**Testing:**
- Unit test with sample Clash configs
- Test Clash Meta extensions (VLESS, Reality)
- Test proxy groups are skipped (not services)

**Verification:**
- Import real Clash config from popular subscription
- All proxies appear as services

**Commit:** `feat: add Clash/Meta YAML config parser`

---

### Task 8: Implement V2Ray Config Parser

**Goal:** Parse V2Ray/Xray JSON configs into Service models.

**Files to touch:**
- `tnl_ctrl/Services/ConfigImporter/V2RayParser.swift` — Create

**Implementation steps:**
1. Create `V2RayParser.swift`:
   - Parse V2Ray JSON format
   - Extract `outbounds` array
   - Map V2Ray protocol names to `ProxyProtocol`
   - Handle V2Ray-specific structures:
     - `streamSettings` (network, security, tlsSettings)
     - `mux` settings
     - `vnext` / `servers` arrays
2. Convert to normalized `settings` dictionary

**Testing:**
- Unit test with V2Ray configs for VMess, VLESS
- Test Xray-specific features (Reality, XTLS)

**Verification:**
- Import V2Ray config exported from v2rayN
- Services display correctly

**Commit:** `feat: add V2Ray/Xray JSON config parser`

---

### Task 9: Implement URI Scheme Parser

**Goal:** Parse proxy URI schemes (ss://, vmess://, vless://, trojan://, socks5://).

**Files to touch:**
- `tnl_ctrl/Services/ConfigImporter/URIParser.swift` — Create

**Implementation steps:**
1. Create `URIParser.swift`:
   - Detect scheme from URL prefix
   - Parse each format:
     - `ss://` — Base64(method:password)@host:port#name or SIP002 format
     - `vmess://` — Base64 JSON
     - `vless://` — UUID@host:port?params#name
     - `trojan://` — password@host:port?params#name
     - `socks5://` — [user:pass@]host:port
   - URL-decode fragment for service name
2. Handle subscription URLs (fetch and parse line-by-line)

**Testing:**
- Unit test each URI format with known-good examples
- Test URL-encoded special characters
- Test subscription with multiple URIs

**Verification:**
- Paste URI from popular proxy provider
- Service imports correctly

**Commit:** `feat: add URI scheme parser for proxy links`

---

### Task 10: Build Import UI in Services Tab

**Goal:** Create the Services tab with import functionality and service list.

**Files to touch:**
- `tnl_ctrl/Views/Settings/ServicesTab.swift` — Implement
- `tnl_ctrl/Views/Settings/ServiceRow.swift` — Create
- `tnl_ctrl/Views/Settings/ImportSheet.swift` — Create

**Implementation steps:**
1. Create `ServiceRow.swift`:
   - Protocol icon (SF Symbol per protocol)
   - Name, server:port
   - Latency badge (color-coded: green <100ms, yellow <300ms, red >300ms)
   - Enable/disable toggle
   - Context menu: Edit, Delete, Test Latency
2. Create `ImportSheet.swift`:
   - Tab: Paste config text
   - Tab: Drag-drop file
   - Tab: Enter subscription URL
   - "Import" button triggers appropriate parser
3. Implement `ServicesTab.swift`:
   - List with `ServiceRow` for each service
   - Toolbar: "Import" button (opens sheet), "Add Server" button (future)
   - Empty state with import prompt
4. Wire up to `AppState.services`

**Testing:**
- Visual: service list displays correctly
- Visual: import sheet tabs work
- Integration: import config → appears in list

**Verification:**
- Import a Clash config via paste
- Services appear in list
- Delete a service → removed from list and disk

**Commit:** `feat: implement Services tab with config import UI`

---

### Phase 3: Privileged Helper (Tasks 11-15)

---

### Task 11: Create Helper Target and XPC Protocol

**Goal:** Set up the privileged helper target and define the XPC communication protocol.

**Files to touch:**
- Create new target: `tnl_ctrl_helper`
- `Shared/XPCProtocol.swift` — Create (shared Swift package or framework)
- `tnl_ctrl_helper/Info.plist` — Configure
- `tnl_ctrl_helper/launchd.plist` — Create

**Implementation steps:**
1. In Xcode: File → New → Target → macOS → Command Line Tool
   - Name: `tnl_ctrl_helper`
   - Bundle ID: `nniel.tnlctrl.helper`
2. Create shared XPC protocol (can be in a local Swift package):
   ```swift
   import Foundation

   @objc public protocol HelperProtocol {
       func startTunnel(configJSON: String, reply: @escaping (Bool, String?) -> Void)
       func stopTunnel(reply: @escaping (Bool, String?) -> Void)
       func getStatus(reply: @escaping (Bool, Int?) -> Void)  // running, PID
   }

   public let helperMachServiceName = "nniel.tnlctrl.helper"
   ```
3. Create `launchd.plist` in helper's Resources:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>nniel.tnlctrl.helper</string>
       <key>MachServices</key>
       <dict>
           <key>nniel.tnlctrl.helper</key>
           <true/>
       </dict>
   </dict>
   </plist>
   ```
4. Set helper's Info.plist to include `SMAuthorizedClients` (main app's code signing requirement)

**Testing:**
- Helper target builds successfully
- Shared protocol compiles in both targets

**Verification:**
- Both targets in Xcode project
- No build errors

**Commit:** `feat: create privileged helper target with XPC protocol`

---

### Task 12: Implement Helper XPC Listener

**Goal:** Set up the XPC service listener in the helper that accepts connections from the main app.

**Files to touch:**
- `tnl_ctrl_helper/main.swift` — Implement XPC listener
- `tnl_ctrl_helper/HelperDelegate.swift` — Create

**Implementation steps:**
1. Create `HelperDelegate.swift`:
   ```swift
   class HelperDelegate: NSObject, NSXPCListenerDelegate, HelperProtocol {
       func listener(_ listener: NSXPCListener,
                     shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
           // Verify caller's code signature matches main app
           guard verifyCodeSignature(connection) else { return false }

           connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
           connection.exportedObject = self
           connection.resume()
           return true
       }

       func startTunnel(configJSON: String, reply: @escaping (Bool, String?) -> Void) {
           // TODO: Implement in Task 13
           reply(false, "Not implemented")
       }

       func stopTunnel(reply: @escaping (Bool, String?) -> Void) {
           reply(false, "Not implemented")
       }

       func getStatus(reply: @escaping (Bool, Int?) -> Void) {
           reply(false, nil)
       }
   }
   ```
2. Implement `main.swift`:
   ```swift
   let delegate = HelperDelegate()
   let listener = NSXPCListener(machServiceName: helperMachServiceName)
   listener.delegate = delegate
   listener.resume()
   RunLoop.main.run()
   ```
3. Implement `verifyCodeSignature()` using Security framework

**Testing:**
- Helper runs without crashing
- Rejects connections from unsigned/wrong-signed clients

**Verification:**
- Run helper manually, observe it stays running
- Check Console.app for XPC registration

**Commit:** `feat: implement XPC listener in privileged helper`

---

### Task 13: Implement SingBoxManager

**Goal:** Manage the sing-box process lifecycle (start, stop, restart on crash).

**Files to touch:**
- `tnl_ctrl_helper/SingBoxManager.swift` — Create
- `tnl_ctrl_helper/HelperDelegate.swift` — Wire up

**Implementation steps:**
1. Add sing-box binary to helper's Resources (Copy Bundle Resources phase)
2. Add geoip.db and geosite.db to Resources
3. Create `SingBoxManager.swift`:
   ```swift
   class SingBoxManager {
       private var process: Process?
       private var configPath: URL { /* temp file path */ }

       func start(configJSON: String) throws {
           // Write config to temp file
           // Launch sing-box with -c configPath
           // Set up termination handler for auto-restart
       }

       func stop() {
           process?.terminate()
           process = nil
       }

       var isRunning: Bool { process?.isRunning ?? false }
       var pid: Int32? { process?.processIdentifier }
   }
   ```
4. Implement crash detection and auto-restart with exponential backoff
5. Log crashes to `~/Library/Logs/tnl_ctrl_helper/`

**Testing:**
- Start sing-box with valid config → process runs
- Stop → process terminates
- Kill process externally → auto-restarts

**Verification:**
- Activity Monitor shows sing-box process
- Crash log written on forced termination

**Commit:** `feat: implement SingBoxManager for sing-box process lifecycle`

---

### Task 14: Implement XPCClient in Main App

**Goal:** Create the client-side XPC wrapper for communicating with the helper.

**Files to touch:**
- `tnl_ctrl/Services/XPCClient.swift` — Create

**Implementation steps:**
1. Create `XPCClient.swift`:
   ```swift
   actor XPCClient {
       static let shared = XPCClient()
       private var connection: NSXPCConnection?

       private func getConnection() -> NSXPCConnection {
           if let conn = connection, conn.isValid { return conn }
           let conn = NSXPCConnection(machServiceName: helperMachServiceName)
           conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
           conn.resume()
           connection = conn
           return conn
       }

       func startTunnel(config: TunnelConfig) async throws {
           let json = try JSONEncoder().encode(config)
           let proxy = getConnection().remoteObjectProxy as! HelperProtocol
           // Call with continuation for async/await
       }

       func stopTunnel() async throws { ... }
       func getStatus() async -> (running: Bool, pid: Int?) { ... }
   }
   ```
2. Handle connection invalidation and reconnection
3. Add error types for XPC failures

**Testing:**
- Unit test: connection established
- Unit test: handle helper not installed gracefully

**Verification:**
- Call getStatus from app → receives response

**Commit:** `feat: add XPCClient for helper communication`

---

### Task 15: Implement SMAppService Helper Installation

**Goal:** Install/update the privileged helper using SMAppService.

**Files to touch:**
- `tnl_ctrl/Services/HelperInstaller.swift` — Create
- `tnl_ctrl/App/AppState.swift` — Add helper status
- `tnl_ctrl/Views/Settings/GeneralTab.swift` — Add install UI

**Implementation steps:**
1. Create `HelperInstaller.swift`:
   ```swift
   import ServiceManagement

   class HelperInstaller {
       static let shared = HelperInstaller()

       var isInstalled: Bool {
           SMAppService.daemon(plistName: "nniel.tnlctrl.helper.plist").status == .enabled
       }

       func install() async throws {
           let service = SMAppService.daemon(plistName: "nniel.tnlctrl.helper.plist")
           try await service.register()
       }

       func uninstall() async throws {
           let service = SMAppService.daemon(plistName: "nniel.tnlctrl.helper.plist")
           try await service.unregister()
       }
   }
   ```
2. Embed helper in main app bundle (Copy Files build phase → Contents/Library/LaunchDaemons)
3. Add install button to GeneralTab
4. Show helper status in GeneralTab

**Testing:**
- Click install → system prompts for admin password
- After install, helper runs on boot
- Uninstall removes helper

**Verification:**
- `launchctl list | grep tnl_ctrl` shows helper
- Helper survives app quit and reboot

**Commit:** `feat: implement helper installation via SMAppService`

---

### Phase 4: Tunnel Configuration (Tasks 16-19)

---

### Task 16: Implement ConfigBuilder (sing-box JSON Generator)

**Goal:** Generate sing-box JSON config from services and routing rules.

**Files to touch:**
- `tnl_ctrl_helper/ConfigBuilder.swift` — Create

**Implementation steps:**
1. Create `ConfigBuilder.swift`:
   ```swift
   struct ConfigBuilder {
       func build(services: [Service], rules: [RoutingRule],
                  chain: [UUID], mode: TunnelMode) -> String {
           var config: [String: Any] = [:]

           // DNS settings
           config["dns"] = buildDNS()

           // Inbounds (TUN)
           config["inbounds"] = buildInbounds(mode: mode)

           // Outbounds (services + direct + block)
           config["outbounds"] = buildOutbounds(services: services, chain: chain)

           // Route rules
           config["route"] = buildRoute(rules: rules, mode: mode)

           return /* JSON string */
       }
   }
   ```
2. Implement `buildInbounds()` — TUN interface config with `auto_route`
3. Implement `buildOutbounds()` — Map services to sing-box outbound format, handle chaining via `detour`
4. Implement `buildRoute()` — Map RoutingRule to sing-box route rules
5. Include geo database paths

**Testing:**
- Unit test: generate config for single service
- Unit test: generate config with multi-hop chain
- Unit test: generate config with split rules

**Verification:**
- Generated JSON is valid (parse with JSONSerialization)
- sing-box accepts generated config (`sing-box check -c config.json`)

**Commit:** `feat: implement ConfigBuilder for sing-box JSON generation`

---

### Task 17: Implement Tunnel Tab UI

**Goal:** Create the routing rules editor and chain builder.

**Files to touch:**
- `tnl_ctrl/Views/Settings/TunnelTab.swift` — Implement
- `tnl_ctrl/Views/Settings/RuleRow.swift` — Create
- `tnl_ctrl/Views/Settings/ChainEditor.swift` — Create

**Implementation steps:**
1. Create `TunnelTab.swift`:
   - Mode picker: Full Tunnel / Split Tunnel
   - Rules list (visible when split mode)
   - Chain editor section
2. Create `RuleRow.swift`:
   - Rule type picker
   - Value text field
   - Outbound picker (direct/proxy/block)
   - Delete button
3. Create `ChainEditor.swift`:
   - List of services in chain order
   - Drag-to-reorder support
   - Add/remove from chain
4. Store tunnel config in AppState with persistence

**Testing:**
- Visual: mode toggle works
- Visual: rules can be added/removed
- Visual: chain reordering works

**Verification:**
- Add rules → persist after restart
- Configure chain → order preserved

**Commit:** `feat: implement Tunnel tab with rules and chain editor`

---

### Task 18: Wire Up Connect/Disconnect

**Goal:** Connect the UI to actually start/stop the tunnel via XPC.

**Files to touch:**
- `tnl_ctrl/App/AppState.swift` — Add connect/disconnect methods
- `tnl_ctrl/Views/MenuBar/MenuBarView.swift` — Wire up toggle
- `tnl_ctrl/Services/ConfigNormalizer.swift` — Create

**Implementation steps:**
1. Create `ConfigNormalizer.swift`:
   - Takes `AppState` (services, rules, chain, mode)
   - Uses `ConfigBuilder` to generate sing-box JSON
   - Resolves credential refs from Keychain
2. Add to `AppState`:
   ```swift
   func connect() async throws {
       isConnecting = true
       defer { isConnecting = false }

       let config = try await ConfigNormalizer.shared.normalize(
           services: services.filter { $0.isEnabled },
           rules: tunnelConfig.rules,
           chain: tunnelConfig.chain,
           mode: tunnelConfig.mode
       )

       try await XPCClient.shared.startTunnel(configJSON: config)
       isConnected = true
   }

   func disconnect() async throws {
       try await XPCClient.shared.stopTunnel()
       isConnected = false
   }
   ```
3. Update `MenuBarView` toggle to call connect/disconnect

**Testing:**
- Click connect → tunnel starts (verify with `networksetup`)
- Click disconnect → tunnel stops
- Status icon updates correctly

**Verification:**
- Traffic routes through proxy (check IP via whatismyip.com)
- Disconnect restores direct connection

**Commit:** `feat: wire up connect/disconnect to XPC helper`

---

### Task 19: Implement Latency Testing

**Goal:** Measure TCP handshake latency to servers.

**Files to touch:**
- `tnl_ctrl/Services/LatencyTester.swift` — Create
- `tnl_ctrl/Views/Settings/ServiceRow.swift` — Add latency display

**Implementation steps:**
1. Create `LatencyTester.swift`:
   ```swift
   actor LatencyTester {
       func test(server: String, port: Int) async -> Int? {
           let start = CFAbsoluteTimeGetCurrent()

           // TCP connect with 5s timeout
           guard let socket = try? await connectTCP(host: server, port: port) else {
               return nil
           }
           socket.close()

           let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
           return Int(elapsed)
       }

       func testAll(_ services: [Service]) async -> [UUID: Int] {
           await withTaskGroup(of: (UUID, Int?).self) { group in
               for service in services {
                   group.addTask {
                       (service.id, await self.test(server: service.server, port: service.port))
                   }
               }
               // Collect results
           }
       }
   }
   ```
2. Use NWConnection for TCP connect
3. Update `ServiceRow` to show latency with color coding
4. Add "Test All" button to ServicesTab toolbar

**Testing:**
- Test reachable server → latency value returned
- Test unreachable server → nil/timeout
- Test all runs in parallel

**Verification:**
- Latency values appear in service list
- Values are reasonable (compare to ping)

**Commit:** `feat: add TCP latency testing for services`

---

### Phase 5: Server Deployment (Tasks 20-24)

---

### Task 20: Implement DockerManager (Local)

**Goal:** Manage local Docker containers via CLI.

**Files to touch:**
- `tnl_ctrl/Services/DockerManager.swift` — Create

**Implementation steps:**
1. Create `DockerManager.swift`:
   ```swift
   actor DockerManager {
       func isDockerAvailable() async -> Bool {
           // Check `docker info` succeeds
       }

       func runContainer(image: String, name: String, ports: [String: Int],
                        env: [String: String], volumes: [String: String]) async throws {
           // Build and execute `docker run` command
       }

       func stopContainer(name: String) async throws { ... }
       func removeContainer(name: String) async throws { ... }
       func getContainerStatus(name: String) async -> ContainerStatus { ... }
   }
   ```
2. Detect Docker socket (Docker Desktop vs colima)
3. Parse JSON output from docker commands
4. Handle common errors (Docker not running, image pull failures)

**Testing:**
- Docker available → returns true
- Run container → container appears in `docker ps`
- Stop/remove → container gone

**Verification:**
- Run nginx container via app
- Verify in Docker Desktop

**Commit:** `feat: implement DockerManager for local containers`

---

### Task 21: Implement SSHClient

**Goal:** Execute commands on remote servers via SSH.

**Files to touch:**
- `tnl_ctrl/Services/SSHClient.swift` — Create

**Implementation steps:**
1. Add SwiftNIO SSH: `https://github.com/apple/swift-nio-ssh`
2. Create `SSHClient.swift`:
   ```swift
   actor SSHClient {
       func connect(host: String, port: Int = 22,
                   username: String, privateKey: String) async throws -> SSHConnection

       func execute(command: String, on connection: SSHConnection) async throws -> String

       func disconnect(_ connection: SSHConnection) async
   }

   struct SSHConnection { /* NIO channel wrapper */ }
   ```
3. Support Ed25519 and RSA private keys
4. Handle host key verification (trust on first use, store in Keychain)

**Testing:**
- Connect to local SSH server → success
- Execute `echo test` → returns "test"
- Wrong key → appropriate error

**Verification:**
- Connect to real VPS
- Execute `docker --version`

**Commit:** `feat: implement SSHClient for remote server access`

---

### Task 22: Create Protocol Templates

**Goal:** Define server-side Docker configurations for each protocol.

**Files to touch:**
- `tnl_ctrl/Wizard/ProtocolTemplates/VLESSTemplate.swift` — Create
- `tnl_ctrl/Wizard/ProtocolTemplates/TrojanTemplate.swift` — Create
- `tnl_ctrl/Wizard/ProtocolTemplates/ShadowsocksTemplate.swift` — Create
- (Additional templates for each protocol)

**Implementation steps:**
1. Create `Wizard/ProtocolTemplates/` directory
2. Define `ProtocolTemplate` protocol:
   ```swift
   protocol ProtocolTemplate {
       var protocolType: ProxyProtocol { get }
       var defaultImage: String { get }
       var requiredPorts: [Int] { get }

       func generateServerConfig(settings: DeploymentSettings) -> String
       func generateClientService(settings: DeploymentSettings) -> Service
       func generateDockerCommand(settings: DeploymentSettings) -> String
   }

   struct DeploymentSettings {
       var serverHost: String
       var port: Int
       var uuid: String  // Auto-generated
       var password: String  // Auto-generated
       // Protocol-specific options
   }
   ```
3. Implement each template with secure defaults:
   - VLESS+Reality with auto-generated keys
   - Trojan with TLS
   - Shadowsocks with AEAD cipher

**Testing:**
- Each template generates valid Docker command
- Generated client config connects to generated server config

**Verification:**
- Deploy VLESS server locally
- Import generated client config
- Connect successfully

**Commit:** `feat: add protocol templates for server deployment`

---

### Task 23: Build Deployment Wizard UI

**Goal:** Create the multi-step wizard for deploying new servers.

**Files to touch:**
- `tnl_ctrl/Wizard/WizardView.swift` — Create
- `tnl_ctrl/Wizard/Steps/TargetStep.swift` — Create
- `tnl_ctrl/Wizard/Steps/ProtocolStep.swift` — Create
- `tnl_ctrl/Wizard/Steps/ConfigureStep.swift` — Create
- `tnl_ctrl/Wizard/Steps/DeployStep.swift` — Create

**Implementation steps:**
1. Create `Wizard/` and `Wizard/Steps/` directories
2. Create `WizardView.swift`:
   ```swift
   struct WizardView: View {
       @State private var step = 0
       @State private var wizardState = WizardState()

       var body: some View {
           VStack {
               // Progress indicator
               switch step {
               case 0: TargetStep(state: $wizardState, onNext: { step = 1 })
               case 1: ProtocolStep(state: $wizardState, onNext: { step = 2 })
               case 2: ConfigureStep(state: $wizardState, onNext: { step = 3 })
               case 3: DeployStep(state: $wizardState, onDone: { /* dismiss */ })
               default: EmptyView()
               }
           }
           .frame(width: 500, height: 400)
       }
   }
   ```
3. Implement each step:
   - TargetStep: Local Docker / Remote Server (SSH details)
   - ProtocolStep: Protocol picker with descriptions
   - ConfigureStep: Port, auto-generated credentials, advanced options
   - DeployStep: Progress log, test connection, import client config
4. Add "Add Server" button to ServicesTab that opens wizard

**Testing:**
- Visual: navigate forward/back through steps
- Visual: validation prevents proceeding with invalid input
- Integration: complete wizard → container deployed

**Verification:**
- Deploy VLESS server to local Docker
- Service appears in list
- Connect successfully

**Commit:** `feat: implement server deployment wizard UI`

---

### Task 24: Implement Remote Deployment

**Goal:** Deploy containers to remote servers via SSH.

**Files to touch:**
- `tnl_ctrl/Wizard/RemoteDeployer.swift` — Create

**Implementation steps:**
1. Create `RemoteDeployer.swift`:
   ```swift
   actor RemoteDeployer {
       func deploy(template: ProtocolTemplate, settings: DeploymentSettings,
                  ssh: SSHConnection, progress: @escaping (String) -> Void) async throws -> Service {
           // 1. Check Docker installed
           progress("Checking Docker...")
           let dockerVersion = try await SSHClient.shared.execute(command: "docker --version", on: ssh)

           // 2. Pull image
           progress("Pulling image...")
           try await SSHClient.shared.execute(command: "docker pull \(template.defaultImage)", on: ssh)

           // 3. Generate and write config
           progress("Configuring...")
           let config = template.generateServerConfig(settings: settings)
           // Write via heredoc or scp

           // 4. Run container
           progress("Starting container...")
           let dockerCmd = template.generateDockerCommand(settings: settings)
           try await SSHClient.shared.execute(command: dockerCmd, on: ssh)

           // 5. Generate client service
           progress("Done!")
           return template.generateClientService(settings: settings)
       }
   }
   ```
2. Handle errors gracefully (Docker not installed, port in use, etc.)
3. Store SSH credentials in Keychain for future management

**Testing:**
- Deploy to test VPS → container runs
- Errors during deployment → appropriate message

**Verification:**
- Deploy to real VPS
- Connect via generated client config

**Commit:** `feat: implement remote server deployment via SSH`

---

### Phase 6: Polish (Tasks 25-28)

---

### Task 25: Implement Config Export

**Goal:** Export services (without secrets) for backup/sharing.

**Files to touch:**
- `tnl_ctrl/Services/ConfigExporter.swift` — Create
- `tnl_ctrl/Views/Settings/ServicesTab.swift` — Add export button

**Implementation steps:**
1. Create `ConfigExporter.swift`:
   ```swift
   struct ConfigExporter {
       func exportToSingBox(services: [Service]) -> String {
           // Generate sing-box config JSON (without credentials populated)
       }

       func exportToClash(services: [Service]) -> String {
           // Generate Clash YAML format
       }

       func exportToURIs(services: [Service]) -> [String] {
           // Generate URI strings for each service
       }
   }
   ```
2. Add export menu to ServicesTab
3. Present save panel for file export

**Testing:**
- Export → reimport → services match (except credentials)
- Exported files are valid format

**Verification:**
- Export Clash config
- Import into another Clash client
- Works (after adding credentials)

**Commit:** `feat: implement config export for backup and sharing`

---

### Task 26: Implement Geo Database Updates

**Goal:** Check for and download updated GeoIP/GeoSite databases.

**Files to touch:**
- `tnl_ctrl/Services/GeoDatabaseUpdater.swift` — Create
- `tnl_ctrl/Views/Settings/GeneralTab.swift` — Add update UI

**Implementation steps:**
1. Create `GeoDatabaseUpdater.swift`:
   ```swift
   actor GeoDatabaseUpdater {
       private let geoipURL = "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db"
       private let geositeURL = "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db"

       func checkForUpdates() async -> Bool {
           // Compare ETag/Last-Modified with stored values
       }

       func update(progress: @escaping (Double) -> Void) async throws {
           // Download to helper's Resources via XPC
       }

       var lastUpdateDate: Date? { /* from UserDefaults */ }
   }
   ```
2. Add "Check for Updates" button in GeneralTab
3. Implement weekly background check (when app launches)
4. Pass updated databases to helper via XPC

**Testing:**
- Check for updates → correct result
- Download updates → files replaced
- Helper uses new databases after restart

**Verification:**
- Force update
- Geo rules still work

**Commit:** `feat: implement geo database update mechanism`

---

### Task 27: Add First Launch Onboarding

**Goal:** Guide new users through initial setup.

**Files to touch:**
- `tnl_ctrl/Views/Onboarding/OnboardingWindow.swift` — Create
- `tnl_ctrl/App/tnl_ctrlApp.swift` — Show on first launch

**Implementation steps:**
1. Create `Views/Onboarding/` directory
2. Create `OnboardingWindow.swift`:
   - Page 1: Welcome, explain menu bar location
   - Page 2: Install helper (with button)
   - Page 3: Import first config or deploy server
   - Page 4: Done, show menu bar location
3. Track first launch in UserDefaults
4. Show onboarding window on first launch

**Testing:**
- Fresh install → onboarding appears
- Complete onboarding → doesn't appear again
- "Show Again" option in General tab

**Verification:**
- Delete app preferences
- Launch → onboarding appears

**Commit:** `feat: add first-launch onboarding flow`

---

### Task 28: Final Polish and Testing

**Goal:** Complete remaining polish and comprehensive testing.

**Files to touch:**
- Various files for bug fixes
- `README.md` — Create

**Implementation steps:**
1. Accessibility audit:
   - VoiceOver labels for all controls
   - Keyboard navigation
2. Error handling review:
   - User-friendly error messages
   - No crashes on edge cases
3. Create README.md:
   - Project description
   - Build instructions
   - Usage guide
   - Screenshots
4. Performance optimization:
   - Profile with Instruments
   - Fix any memory leaks
5. Final testing matrix:
   - [ ] Clean install flow
   - [ ] Import each config format
   - [ ] Deploy local server
   - [ ] Deploy remote server
   - [ ] Full tunnel mode
   - [ ] Split tunnel mode
   - [ ] Multi-hop chain
   - [ ] Latency testing
   - [ ] Config export
   - [ ] Geo database update
   - [ ] Helper install/uninstall
   - [ ] App restart preserves state

**Verification:**
- All matrix items pass
- No console errors during normal use

**Commit:** `chore: final polish and testing`

---

## 5. Testing Strategy

### Test Types
- **Unit tests:** Models, parsers, config builder
- **Integration tests:** XPC communication, Docker commands
- **Manual tests:** UI flows, tunnel connectivity

### Test Location
- `tnl_ctrl_tests/` — Unit tests
- `tnl_ctrlUITests/` — UI tests (optional)

### Running Tests
```fish
# Run all tests
xcodebuild test -scheme tnl_ctrl -destination 'platform=macOS'

# Run specific test file
xcodebuild test -scheme tnl_ctrl -only-testing:tnl_ctrl_tests/ServiceTests
```

### Coverage Expectations
- Models: 90%+
- Parsers: 80%+
- UI: Manual testing sufficient

## 6. Documentation Updates

- `README.md` — Project overview, build instructions, usage
- `docs/brainstorms/tunnelmaster-design.md` — Already exists
- `docs/plans/tunnelmaster-implementation.md` — This document
- Code comments: Only for non-obvious logic

## 7. Definition of Done

- [ ] All 28 tasks implemented
- [ ] Unit tests passing
- [ ] Manual test matrix complete
- [ ] Helper installs correctly
- [ ] Tunnel connects and routes traffic
- [ ] Config import works for all formats
- [ ] Server deployment works (local + remote)
- [ ] No crashes during normal use
- [ ] README complete
- [ ] Code reviewed (self-review for solo project)

---

*Generated via /brainstorm-plan on 2026-01-13*

*Use this plan as a reference while implementing with Claude Code's plan mode for actual execution.*
