//
//  GeneralTab.swift
//  TunnelMaster
//

import SwiftUI

struct GeneralTab: View {
    @State private var helperInstaller = HelperInstaller.shared
    @State private var installError: String?
    @State private var isInstalling = false

    var body: some View {
        Form {
            Section("Privileged Helper") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("TunnelMaster Helper")
                            .font(.headline)
                        Text("Required for system-wide tunneling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if helperInstaller.isChecking || isInstalling {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        statusIcon
                    }
                }

                if let error = installError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                helperActions
            }

            Section("Geo Databases") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("GeoIP / GeoSite")
                            .font(.headline)
                        Text("Used for geo-based routing rules")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Check for Updates") {
                        // TODO: Task 26 - Geo database updates
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0 (1)")
                LabeledContent("sing-box", value: "v1.10.0 (bundled)")

                Link("View on GitHub", destination: URL(string: "https://github.com")!)
            }
        }
        .formStyle(.grouped)
        .task {
            await helperInstaller.checkStatus()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch helperInstaller.status {
        case .installed:
            Label("Running", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .installedNotRunning:
            Label("Not Running", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .notInstalled:
            Label("Not Installed", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .requiresApproval:
            Label("Needs Approval", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .installing:
            Label("Installing...", systemImage: "arrow.clockwise")
                .foregroundStyle(.blue)
        case .unknown:
            Label("Unknown", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var helperActions: some View {
        switch helperInstaller.status {
        case .notInstalled, .unknown:
            Button("Install Helper...") {
                Task {
                    await installHelper()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isInstalling)

        case .requiresApproval:
            VStack(alignment: .leading, spacing: 8) {
                Text("Please approve TunnelMaster in System Settings > Login Items")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                    }

                    Button("Check Again") {
                        Task {
                            await helperInstaller.checkStatus()
                        }
                    }
                }
            }

        case .installed, .installedNotRunning:
            HStack {
                Button("Check Status") {
                    Task {
                        await helperInstaller.checkStatus()
                    }
                }

                Button("Uninstall Helper", role: .destructive) {
                    Task {
                        await uninstallHelper()
                    }
                }
            }

        case .installing:
            EmptyView()
        }
    }

    private func installHelper() async {
        isInstalling = true
        installError = nil

        do {
            try await helperInstaller.install()
        } catch {
            installError = error.localizedDescription
        }

        isInstalling = false
    }

    private func uninstallHelper() async {
        isInstalling = true
        installError = nil

        do {
            try await helperInstaller.uninstall()
        } catch {
            installError = error.localizedDescription
        }

        isInstalling = false
    }
}
