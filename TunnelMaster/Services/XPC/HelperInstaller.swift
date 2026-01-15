//
//  HelperInstaller.swift
//  TunnelMaster
//
//  Manages installation and status of the privileged helper via SMAppService.
//

import Foundation
import ServiceManagement

@Observable
final class HelperInstaller {
    static let shared = HelperInstaller()

    private(set) var status: HelperStatus = .unknown
    private(set) var isChecking = false

    private var daemonService: SMAppService {
        SMAppService.daemon(plistName: "nniel.TunnelMaster.helper.plist")
    }

    private init() {
        Task {
            await checkStatus()
        }
    }

    // MARK: - Status

    @MainActor
    func checkStatus() async {
        isChecking = true
        defer { isChecking = false }

        let serviceStatus = daemonService.status

        switch serviceStatus {
        case .notRegistered:
            status = .notInstalled
        case .enabled:
            // Check if actually responding
            let responding = await XPCClient.shared.isHelperResponding()
            status = responding ? .installed : .installedNotRunning
        case .requiresApproval:
            status = .requiresApproval
        case .notFound:
            status = .notInstalled
        @unknown default:
            status = .unknown
        }
    }

    // MARK: - Installation

    @MainActor
    func install() async throws {
        status = .installing

        do {
            try daemonService.register()

            // Wait a moment for the service to start
            try await Task.sleep(for: .seconds(1))

            await checkStatus()

            if status != .installed {
                throw HelperInstallerError.installFailed("Helper registered but not responding")
            }
        } catch let error as NSError {
            await checkStatus()

            // Check for specific errors
            if error.domain == "SMAppServiceErrorDomain" {
                switch error.code {
                case 1: // User denied
                    throw HelperInstallerError.userDenied
                case 2: // Already registered
                    await checkStatus()
                    return
                default:
                    throw HelperInstallerError.installFailed(error.localizedDescription)
                }
            }

            throw HelperInstallerError.installFailed(error.localizedDescription)
        }
    }

    // MARK: - Uninstallation

    @MainActor
    func uninstall() async throws {
        do {
            try await daemonService.unregister()
            status = .notInstalled
        } catch {
            throw HelperInstallerError.uninstallFailed(error.localizedDescription)
        }
    }
}

// MARK: - Status Enum

enum HelperStatus: Sendable {
    case unknown
    case notInstalled
    case installing
    case installed
    case installedNotRunning
    case requiresApproval

    var displayName: String {
        switch self {
        case .unknown: "Checking..."
        case .notInstalled: "Not Installed"
        case .installing: "Installing..."
        case .installed: "Installed & Running"
        case .installedNotRunning: "Installed (Not Running)"
        case .requiresApproval: "Requires Approval"
        }
    }

    var isInstalled: Bool {
        switch self {
        case .installed, .installedNotRunning:
            return true
        default:
            return false
        }
    }
}

// MARK: - Errors

enum HelperInstallerError: LocalizedError {
    case installFailed(String)
    case uninstallFailed(String)
    case userDenied

    var errorDescription: String? {
        switch self {
        case let .installFailed(detail):
            "Failed to install helper: \(detail)"
        case let .uninstallFailed(detail):
            "Failed to uninstall helper: \(detail)"
        case .userDenied:
            "Installation was denied. Please allow TunnelMaster in System Settings > Login Items."
        }
    }
}
