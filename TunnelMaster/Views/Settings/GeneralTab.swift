//
//  GeneralTab.swift
//  TunnelMaster
//

import ServiceManagement
import SwiftUI

private enum URLs {
    // swiftlint:disable:next force_unwrapping
    static let github = URL(string: "https://github.com")!
    // swiftlint:disable:next force_unwrapping
    static let loginItemsSettings = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
}

struct GeneralTab: View {
    @Environment(AppState.self) private var appState
    @State private var helperInstaller = HelperInstaller.shared
    @State private var geoUpdater = GeoDatabaseUpdater.shared
    @State private var installError: String?
    @State private var isInstalling = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

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

                        if let lastUpdate = geoUpdater.lastUpdateDate {
                            Text("Last updated: \(lastUpdate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if geoUpdater.hasLocalDatabases() {
                            Text("Databases installed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not installed")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    if geoUpdater.isUpdating {
                        ProgressView(value: geoUpdater.updateProgress)
                            .frame(width: 100)
                    } else if geoUpdater.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if geoUpdater.updateAvailable {
                        Button("Update Now") {
                            Task { await geoUpdater.update() }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Check for Updates") {
                            Task { await geoUpdater.checkForUpdates() }
                        }
                    }
                }

                if let error = geoUpdater.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Debugging") {
                @Bindable var state = appState
                Toggle("Enable sing-box logs", isOn: $state.settings.enableSingBoxLogs)
                    .onChange(of: appState.settings.enableSingBoxLogs) { _, _ in
                        appState.saveSettings()
                    }

                if appState.settings.enableSingBoxLogs {
                    Button("Open Logs in Finder") {
                        let logURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("TunnelMasterHelper")
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logURL.path)
                    }

                    Text("Logs are written to: sing-box.log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Enable logs to capture sing-box output for debugging. Takes effect on next connect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0 (1)")
                LabeledContent("sing-box") {
                    if singBoxBundled {
                        Text("v1.12.22 (bundled)")
                    } else {
                        Label("v1.12.22 (Homebrew fallback)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                Link("View on GitHub", destination: URLs.github)
            }
        }
        .formStyle(.grouped)
        .task {
            await helperInstaller.checkStatus()
        }
    }

    @ViewBuilder private var statusIcon: some View {
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

    @ViewBuilder private var helperActions: some View {
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
                        NSWorkspace.shared.open(URLs.loginItemsSettings)
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

    private var singBoxBundled: Bool {
        let singBoxURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons/sing-box")
        return FileManager.default.fileExists(atPath: singBoxURL.path)
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
