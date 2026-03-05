//
//  LocalDeploymentIntegrationTests.swift
//  tnl_ctrl_tests
//
//  Integration tests that deploy real Docker containers for each protocol
//  and verify they start correctly. Requires Docker to be running.
//

@testable import tnl_ctrl
import XCTest

// swiftlint:disable type_body_length file_length

@MainActor
final class LocalDeploymentIntegrationTests: XCTestCase {
    private let dockerManager = DockerManager.shared
    private var createdContainers: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        guard await dockerManager.isDockerAvailable() else {
            throw XCTSkip("Docker not available — skipping integration tests")
        }
    }

    override func tearDown() async throws {
        for name in createdContainers {
            try? await dockerManager.removeContainer(name: name, force: true)
            cleanupConfigDirs(containerName: name)
        }
        createdContainers.removeAll()
        // Allow Docker to release ports before the next test
        try await Task.sleep(for: .milliseconds(500))
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeDeployer(
        protocol proto: ProxyProtocol,
        port: Int,
        configure: (WizardState) -> Void = { _ in }
    ) -> (Deployer, WizardState, Server) {
        let server = Server(
            name: "Integration Test",
            host: "localhost",
            deploymentTarget: .local
        )
        let state = WizardState(server: server)
        state.selectedProtocol = proto
        state.serverPort = port
        configure(state)
        return (Deployer(state: state), state, server)
    }

    /// Deploys and tracks the container name for cleanup. For sing-box based templates
    /// (VLESS, VMess, Trojan), pre-generates TLS certificates so the container starts.
    @discardableResult
    private func deployAndTrack(
        deployer: Deployer,
        server: Server,
        state: WizardState
    ) async throws -> Service {
        let settings = state.buildDeploymentSettings()
        createdContainers.append(settings.containerName)

        // Sing-box templates reference TLS cert/key files that the Deployer doesn't create.
        // Pre-generate self-signed certs so the container can start.
        let proto = state.selectedProtocol
        if proto == .vless || proto == .vmess || proto == .trojan {
            let dir = Deployer.containerConfigDir.appendingPathComponent("sing-box-\(settings.containerName)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try generateTestCerts(
                in: dir,
                host: settings.sni.isEmpty ? settings.serverHost : settings.sni
            )
        }

        return try await deployer.deploy(to: server)
    }

    /// Generates a self-signed TLS certificate for testing.
    private func generateTestCerts(in directory: URL, host: String) throws {
        let certPath = directory.appendingPathComponent("cert.pem").path
        let keyPath = directory.appendingPathComponent("key.pem").path
        let cn = host.isEmpty ? "localhost" : host

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "req", "-x509", "-newkey", "rsa:2048",
            "-days", "1", "-nodes",
            "-keyout", keyPath,
            "-out", certPath,
            "-subj", "/CN=\(cn)",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "TestCerts", code: 1, userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    private func assertContainerRunning(
        _ containerName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let status = await dockerManager.getContainerStatus(name: containerName)
        XCTAssertEqual(
            status, .running,
            "Container '\(containerName)' should be running, got \(status)",
            file: file, line: line
        )
    }

    private func containerName(from service: Service) throws -> String {
        try XCTUnwrap(service.settings["containerName"]?.stringValue)
    }

    private func configDir(for containerName: String, prefix: String) -> URL {
        Deployer.containerConfigDir.appendingPathComponent("\(prefix)\(containerName)")
    }

    private func cleanupConfigDirs(containerName: String) {
        for prefix in ["sing-box-", "hysteria-", "wireguard-"] {
            let dir = configDir(for: containerName, prefix: prefix)
            try? FileManager.default.removeItem(at: dir)
        }
    }

    private func assertServiceBasics(
        _ service: Service,
        protocol proto: ProxyProtocol,
        port: Int,
        serverId: UUID,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(service.protocol, proto, file: file, line: line)
        XCTAssertEqual(service.server, "localhost", file: file, line: line)
        XCTAssertEqual(service.port, port, file: file, line: line)
        XCTAssertEqual(service.source, .created, file: file, line: line)
        XCTAssertEqual(service.serverId, serverId, file: file, line: line)
        _ = try containerName(from: service)
    }

    // MARK: - Basic Deployment Tests (one per protocol)

    func testVLESSLocalDeploy() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .vless, port: 41001)
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)

        try assertServiceBasics(service, protocol: .vless, port: 41001, serverId: server.id)
        try await assertContainerRunning(containerName(from: service))

        XCTAssertNotNil(service.settings["uuid"]?.stringValue)
        XCTAssertNotNil(service.settings["flow"]?.stringValue)
        XCTAssertEqual(service.settings["tls"]?.boolValue, true)
    }

    func testVMessLocalDeploy() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .vmess, port: 41002)
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)

        try assertServiceBasics(service, protocol: .vmess, port: 41002, serverId: server.id)
        try await assertContainerRunning(containerName(from: service))

        XCTAssertNotNil(service.settings["uuid"]?.stringValue)
        XCTAssertEqual(service.settings["alterId"]?.intValue, 0)
        XCTAssertEqual(service.settings["security"]?.stringValue, "auto")
    }

    func testTrojanLocalDeploy() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .trojan, port: 41003)
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)

        try assertServiceBasics(service, protocol: .trojan, port: 41003, serverId: server.id)
        try await assertContainerRunning(containerName(from: service))

        XCTAssertNotNil(service.settings["password"]?.stringValue)
        XCTAssertEqual(service.settings["tls"]?.boolValue, true)
    }

    func testShadowsocksLocalDeploy() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .shadowsocks, port: 41004)
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)

        try assertServiceBasics(service, protocol: .shadowsocks, port: 41004, serverId: server.id)
        try await assertContainerRunning(containerName(from: service))

        XCTAssertNotNil(service.settings["password"]?.stringValue)
        XCTAssertEqual(service.settings["method"]?.stringValue, "aes-256-gcm")
    }

    func testHysteria2LocalDeploy() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .hysteria2, port: 41005) { state in
            state.hysteriaDomain = "test.example.com"
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)

        try assertServiceBasics(service, protocol: .hysteria2, port: 41005, serverId: server.id)
        try await assertContainerRunning(containerName(from: service))

        XCTAssertNotNil(service.settings["password"]?.stringValue)
        XCTAssertEqual(service.settings["tls"]?.boolValue, true)
        XCTAssertEqual(service.settings["allowInsecure"]?.boolValue, true)
    }

    func testWireGuardLocalDeploy() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .wireguard, port: 41006) { state in
            state.wgAdminPassword = "testpassword"
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)

        try assertServiceBasics(service, protocol: .wireguard, port: 41006, serverId: server.id)
        try await assertContainerRunning(containerName(from: service))

        XCTAssertEqual(service.settings["web_ui_port"]?.intValue, 51821)
        XCTAssertNotNil(service.settings["note"]?.stringValue)
    }

    // MARK: - Config File Verification

    func testVLESSConfigFileWritten() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .vless, port: 41011)
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        let configFile = configDir(for: name, prefix: "sing-box-").appendingPathComponent("config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configFile.path), "config.json should exist")

        let data = try Data(contentsOf: configFile)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inbounds = try XCTUnwrap(json["inbounds"] as? [[String: Any]])
        XCTAssertEqual(inbounds.first?["type"] as? String, "vless")
        XCTAssertEqual(inbounds.first?["listen_port"] as? Int, 41011)
    }

    func testHysteria2ConfigFileWritten() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .hysteria2, port: 41012) { state in
            state.hysteriaDomain = "hy2-test.example.com"
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        let configFile = configDir(for: name, prefix: "hysteria-").appendingPathComponent("hysteria.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configFile.path), "hysteria.yaml should exist")

        let content = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertTrue(content.contains("listen:"), "Config should contain listen directive")
        XCTAssertTrue(content.contains("auth:"), "Config should contain auth section")
        XCTAssertTrue(content.contains("password:"), "Config should contain password")
    }

    func testHysteria2TLSCertsGenerated() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .hysteria2, port: 41013) { state in
            state.hysteriaDomain = "cert-test.example.com"
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        let dir = configDir(for: name, prefix: "hysteria-")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("cert.pem").path), "cert.pem should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("key.pem").path), "key.pem should exist")
    }

    func testWireGuardNoConfigFile() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .wireguard, port: 41014) { state in
            state.wgAdminPassword = "testpass"
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        // WireGuard uses env vars, no config.json should be written
        let configFile = configDir(for: name, prefix: "wireguard-").appendingPathComponent("config.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: configFile.path), "WireGuard should not have config.json")
    }

    func testShadowsocksConfigContainsMethod() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .shadowsocks, port: 41015)
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        let configFile = configDir(for: name, prefix: "sing-box-").appendingPathComponent("config.json")
        let data = try Data(contentsOf: configFile)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inbounds = try XCTUnwrap(json["inbounds"] as? [[String: Any]])
        XCTAssertEqual(inbounds.first?["method"] as? String, "aes-256-gcm")
        XCTAssertNotNil(inbounds.first?["password"] as? String)
    }

    // MARK: - Protocol-Specific Edge Cases

    func testVMessWithTLSDisabled() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .vmess, port: 41022)
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        try await assertContainerRunning(name)

        let configFile = configDir(for: name, prefix: "sing-box-").appendingPathComponent("config.json")
        let data = try Data(contentsOf: configFile)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inbounds = try XCTUnwrap(json["inbounds"] as? [[String: Any]])
        XCTAssertEqual(inbounds.first?["type"] as? String, "vmess")
    }

    func testHysteria2WithObfuscation() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .hysteria2, port: 41023) { state in
            state.hysteriaDomain = "obfs-test.example.com"
            state.hysteriaObfsEnabled = true
            state.hysteriaObfsPassword = "test-obfs-password"
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        try await assertContainerRunning(name)

        let configFile = configDir(for: name, prefix: "hysteria-").appendingPathComponent("hysteria.yaml")
        let content = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertTrue(content.contains("obfs:"), "Config should contain obfs section")
        XCTAssertTrue(content.contains("salamander"), "Obfs type should be salamander")
        XCTAssertTrue(content.contains("test-obfs-password"), "Obfs password should be present")

        XCTAssertEqual(service.settings["obfs_type"]?.stringValue, "salamander")
        XCTAssertEqual(service.settings["obfs"]?.stringValue, "test-obfs-password")
    }

    func testHysteria2WithoutObfuscation() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .hysteria2, port: 41024) { state in
            state.hysteriaDomain = "no-obfs.example.com"
            state.hysteriaObfsEnabled = false
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        try await assertContainerRunning(name)

        let configFile = configDir(for: name, prefix: "hysteria-").appendingPathComponent("hysteria.yaml")
        let content = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertFalse(content.contains("obfs:"), "Config should not contain obfs section")

        XCTAssertNil(service.settings["obfs_type"])
        XCTAssertNil(service.settings["obfs"])
    }

    func testHysteria2WithMasquerade() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .hysteria2, port: 41025) { state in
            state.hysteriaDomain = "masq.example.com"
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        try await assertContainerRunning(name)

        let configFile = configDir(for: name, prefix: "hysteria-").appendingPathComponent("hysteria.yaml")
        let content = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertTrue(content.contains("masquerade:"), "Config should contain masquerade section when SNI is set")
        XCTAssertTrue(content.contains("masq.example.com"), "Masquerade should reference the domain")
    }

    func testWireGuardWithAdminPassword() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .wireguard, port: 41026) { state in
            state.wgAdminPassword = "admin-test-pass"
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        try await assertContainerRunning(containerName(from: service))
    }

    func testWireGuardWithoutAdminPassword() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .wireguard, port: 41027) { state in
            state.wgAdminPassword = ""
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        try await assertContainerRunning(containerName(from: service))
    }

    func testCustomServiceName() async throws {
        let customName = "My Custom Shadowsocks Service"
        let (deployer, state, server) = makeDeployer(protocol: .shadowsocks, port: 41028) { state in
            state.serviceName = customName
        }
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)

        XCTAssertEqual(service.name, customName)
        try await assertContainerRunning(containerName(from: service))
    }

    // MARK: - Deployment Lifecycle Edge Cases

    func testRedeployAfterRemoval() async throws {
        // First deployment (Shadowsocks — no TLS, simplest)
        let (deployer1, state1, server1) = makeDeployer(protocol: .shadowsocks, port: 41031)
        let service1 = try await deployAndTrack(deployer: deployer1, server: server1, state: state1)
        let name1 = try containerName(from: service1)
        await assertContainerRunning(name1)

        // Remove the container
        try await dockerManager.removeContainer(name: name1, force: true)
        cleanupConfigDirs(containerName: name1)

        // Second deployment (new WizardState generates new identity)
        let (deployer2, state2, server2) = makeDeployer(protocol: .shadowsocks, port: 41031)
        let service2 = try await deployAndTrack(deployer: deployer2, server: server2, state: state2)
        let name2 = try containerName(from: service2)
        await assertContainerRunning(name2)

        XCTAssertNotEqual(name1, name2)
    }

    func testDeploymentProgressLogged() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .shadowsocks, port: 41032)
        _ = try await deployAndTrack(deployer: deployer, server: server, state: state)

        XCTAssertFalse(state.deploymentProgress.isEmpty, "Deployment should log progress messages")
        let allProgress = state.deploymentProgress.joined(separator: "\n")
        XCTAssertTrue(allProgress.contains("Docker"), "Progress should mention Docker check")
        XCTAssertTrue(allProgress.contains("complete"), "Progress should indicate completion")
    }

    func testContainerUsesCorrectImage() async throws {
        let (deployer, state, server) = makeDeployer(protocol: .shadowsocks, port: 41033)
        let service = try await deployAndTrack(deployer: deployer, server: server, state: state)
        let name = try containerName(from: service)

        let containers = await dockerManager.listContainers()
        let container = containers.first { $0.name == name }
        XCTAssertNotNil(container, "Container should be in docker ps")
        XCTAssertTrue(
            container?.image.contains("sing-box") == true,
            "Container should use sing-box image, got: \(container?.image ?? "nil")"
        )
    }

    // MARK: - Error Handling

    func testDeployUnsupportedProtocol() async throws {
        let server = Server(name: "Test", host: "localhost", deploymentTarget: .local)
        let state = WizardState(server: server)
        state.selectedProtocol = .socks5
        let deployer = Deployer(state: state)

        do {
            _ = try await deployer.deploy(to: server)
            XCTFail("Should throw unsupportedProtocol error")
        } catch let error as DeployerError {
            guard case .unsupportedProtocol = error else {
                XCTFail("Expected unsupportedProtocol, got: \(error)")
                return
            }
        }
    }
}

// swiftlint:enable type_body_length file_length
