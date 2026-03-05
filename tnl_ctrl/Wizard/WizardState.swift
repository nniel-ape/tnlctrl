//
//  WizardState.swift
//  tnl_ctrl
//
//  State management for the server deployment wizard.
//

import Foundation

@Observable
@MainActor
final class WizardState {
    /// Step tracking
    var currentStep = 1

    /// Server to deploy to (required)
    let server: Server

    // Target selection (derived from server)
    var deploymentTarget: DeploymentTarget
    var sshHost: String
    var sshPort: Int
    var sshUsername: String
    var sshKeyPath: String

    // MARK: - Computed Steps

    let totalSteps = 3
    let minStep = 1

    /// Ports already in use by other services on the same server
    let usedPorts: Set<Int>

    /// Container names already in use on the same server
    let usedContainerNames: Set<String>

    // MARK: - Initializer

    init(server: Server, usedPorts: Set<Int> = [], usedContainerNames: Set<String> = []) {
        self.server = server
        self.usedPorts = usedPorts
        self.usedContainerNames = usedContainerNames
        self.deploymentTarget = server.deploymentTarget
        self.sshHost = server.host
        self.sshPort = server.sshPort
        self.sshUsername = server.sshUsername
        self.sshKeyPath = server.sshKeyPath ?? ""
        self.serverPort = Self.availablePort(preferred: ProxyProtocol.vless.defaultPort, usedPorts: usedPorts)
    }

    /// Protocol selection
    var selectedProtocol: ProxyProtocol = .vless {
        didSet {
            serverPort = Self.availablePort(preferred: selectedProtocol.defaultPort, usedPorts: usedPorts)
            cachedIdentity = nil
        }
    }

    /// Cached random identity (uuid, password, containerName) — stable across a single deploy flow.
    /// Only these fields are cached; all other settings are read fresh from current UI state.
    private var cachedIdentity: (uuid: String, password: String, containerName: String)?

    // Configuration
    var serverPort = 443
    var useReality = false

    // Hysteria2 specific
    var hysteriaBandwidthUp = "100"
    var hysteriaBandwidthDown = "100"
    var hysteriaObfsEnabled = false
    var hysteriaObfsPassword = ""

    // WireGuard specific
    var wgAdminPassword = ""
    var wgDefaultDNS = "1.1.1.1"

    /// Custom naming
    var serviceName = ""

    // Deployment
    var isDeploying = false
    var deploymentProgress: [String] = []
    var deploymentError: String?
    var deployedService: Service?

    // MARK: - Computed Names

    var defaultServiceName: String {
        "\(selectedProtocol.displayName) - \(server.name)"
    }

    var effectiveServiceName: String {
        serviceName.trimmingCharacters(in: .whitespaces).isEmpty ? defaultServiceName : serviceName
    }

    // MARK: - Computed

    var canProceed: Bool {
        switch currentStep {
        case 1: // Protocol step
            return true
        case 2: // Configure step
            return serverPort > 0 && serverPort < 65536
        case 3: // Deploy step
            return deployedService != nil
        default:
            return false
        }
    }

    var stepTitle: String {
        switch currentStep {
        case 1: "Choose Protocol"
        case 2: "Configure Service"
        case 3: "Deploy"
        default: ""
        }
    }

    // MARK: - Actions

    func nextStep() {
        if currentStep < minStep + totalSteps - 1 {
            currentStep += 1
        }
    }

    func previousStep() {
        if currentStep > minStep {
            currentStep -= 1
        }
    }

    /// Returns the preferred port if available, otherwise a random unused port.
    static func availablePort(preferred: Int, usedPorts: Set<Int>) -> Int {
        guard usedPorts.contains(preferred) else { return preferred }
        for _ in 0 ..< 100 {
            let port = Int.random(in: 10000 ... 60000)
            if !usedPorts.contains(port) { return port }
        }
        return preferred
    }

    /// Generates a container name that doesn't collide with existing ones on the server.
    static func uniqueContainerName(usedNames: Set<String>) -> String {
        for _ in 0 ..< 100 {
            let name = "tnlctrl-\(Int.random(in: 1000 ... 9999))"
            if !usedNames.contains(name) { return name }
        }
        // Fallback: append extra digits to guarantee uniqueness
        return "tnlctrl-\(Int.random(in: 100_000 ... 999_999))"
    }

    func reset() {
        currentStep = minStep
        selectedProtocol = .vless
        serverPort = Self.availablePort(preferred: ProxyProtocol.vless.defaultPort, usedPorts: usedPorts)
        useReality = false
        // Hysteria2
        hysteriaBandwidthUp = "100"
        hysteriaBandwidthDown = "100"
        hysteriaObfsEnabled = false
        hysteriaObfsPassword = ""
        // WireGuard
        wgAdminPassword = ""
        wgDefaultDNS = "1.1.1.1"
        // Custom naming
        serviceName = ""
        // Deployment
        isDeploying = false
        deploymentProgress = []
        deploymentError = nil
        deployedService = nil
        cachedIdentity = nil
    }

    func buildDeploymentSettings() -> DeploymentSettings {
        // Ensure stable random identity across calls within a single deploy flow
        let identity: (uuid: String, password: String, containerName: String)
        if let cached = cachedIdentity {
            identity = cached
        } else {
            identity = (
                uuid: UUID().uuidString,
                password: DeploymentSettings.generateSecurePassword(),
                containerName: DeploymentSettings.sanitizeContainerName(
                    Self.uniqueContainerName(usedNames: usedContainerNames)
                )
            )
            cachedIdentity = identity
        }

        // Always read current UI state for all configurable fields
        var settings = DeploymentSettings(
            serverHost: deploymentTarget == .local ? "localhost" : sshHost,
            port: serverPort,
            uuid: identity.uuid,
            password: identity.password,
            containerName: identity.containerName
        )

        // VLESS Reality
        settings.realityEnabled = useReality

        // Hysteria2
        settings.hysteriaBandwidthUp = hysteriaBandwidthUp
        settings.hysteriaBandwidthDown = hysteriaBandwidthDown
        settings.hysteriaObfsType = hysteriaObfsEnabled ? "salamander" : ""
        settings.hysteriaObfsPassword = hysteriaObfsPassword

        // WireGuard
        settings.wgAdminPassword = wgAdminPassword
        settings.wgDefaultDNS = wgDefaultDNS

        // Custom naming
        settings.serviceName = effectiveServiceName

        return settings
    }

    func log(_ message: String) {
        deploymentProgress.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }
}

// MARK: - Deployment Target

enum DeploymentTarget: String, Codable, CaseIterable, Identifiable {
    case local
    case remote

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .local: "Local Docker"
        case .remote: "Remote Server (SSH)"
        }
    }

    var description: String {
        switch self {
        case .local: "Deploy to Docker on this Mac"
        case .remote: "Deploy to a remote VPS via SSH"
        }
    }

    var systemImage: String {
        switch self {
        case .local: "desktopcomputer"
        case .remote: "server.rack"
        }
    }
}
