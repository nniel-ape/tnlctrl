//
//  GeneralTab.swift
//  tnl_ctrl
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
    @Environment(UpdaterViewModel.self) private var updaterViewModel
    @State private var helperInstaller = HelperInstaller.shared
    @State private var geoUpdater = GeoDatabaseUpdater.shared
    @State private var installError: String?
    @State private var isInstalling = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var importExportError: String?
    @State private var pendingImportBundle: ConfigBundle?
    @State private var showImportConfirmation = false

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

            configurationSection

            Section("Privileged Helper") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("tnl_ctrl Helper")
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

            Section("Security") {
                @Bindable var state = appState
                Picker("Certificate Store", selection: $state.settings.certificateStore) {
                    Text("System (Default)").tag(CertificateStore.system)
                    Text("Chrome Root Store").tag(CertificateStore.chrome)
                    Text("Mozilla Root Store").tag(CertificateStore.mozilla)
                }
                .onChange(of: appState.settings.certificateStore) { _, _ in
                    appState.saveSettings()
                }

                Text("Chrome and Mozilla stores exclude China-based Certificate Authorities. Takes effect on next connect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Debugging") {
                @Bindable var state2 = appState
                Toggle("Enable sing-box logs", isOn: $state2.settings.enableSingBoxLogs)
                    .onChange(of: appState.settings.enableSingBoxLogs) { _, _ in
                        appState.saveSettings()
                    }

                if appState.settings.enableSingBoxLogs {
                    Button("Open Logs in Finder") {
                        let logURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("tnl_ctrl_helper")
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
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                }
                LabeledContent("sing-box") {
                    if singBoxBundled {
                        Text("v\(SingBoxVersion.current) (bundled)")
                    } else {
                        Label("v\(SingBoxVersion.current) (Homebrew fallback)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                Link("View on GitHub", destination: URLs.github)

                Button("Check for Updates...") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
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
                Text("Please approve tnl_ctrl in System Settings > Login Items")
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

    private var configurationSection: some View {
        Section("Configuration") {
            HStack {
                VStack(alignment: .leading) {
                    Text("Export")
                        .font(.headline)
                    Text("Save all services, servers, rules, presets, and credentials to a file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Export...") {
                    Task { await performExport() }
                }
                .disabled(isExporting)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Import")
                        .font(.headline)
                    Text("Replace all configuration from a previously exported file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Import...") {
                    performImportRead()
                }
                .disabled(isImporting)
            }

            if let error = importExportError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .confirmationDialog(
            "Import Configuration",
            isPresented: $showImportConfirmation,
            presenting: pendingImportBundle
        ) { bundle in
            Button("Import", role: .destructive) {
                Task { await performImportApply(bundle) }
            }
        } message: { bundle in
            Text(importConfirmationMessage(for: bundle))
        }
    }

    private var singBoxBundled: Bool {
        let singBoxURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons/sing-box")
        return FileManager.default.fileExists(atPath: singBoxURL.path)
    }

    // MARK: - Config Export/Import

    private func importConfirmationMessage(for bundle: ConfigBundle) -> String {
        """
        This will replace your entire configuration with:
        \(bundle.services.count) services, \(bundle.servers.count) servers, \
        \(bundle.tunnelConfig.rules.count) rules, \(bundle.presets.count) presets

        Exported \(bundle.exportedAt.formatted(date: .abbreviated, time: .shortened)) \
        (v\(bundle.appVersion))

        This action cannot be undone.
        """
    }

    private func performExport() async {
        isExporting = true
        importExportError = nil
        defer { isExporting = false }

        do {
            let manager = ConfigBundleManager(appState: appState)
            try await manager.exportConfig()
        } catch {
            importExportError = error.localizedDescription
        }
    }

    private func performImportRead() {
        importExportError = nil

        do {
            let manager = ConfigBundleManager(appState: appState)
            guard let bundle = try manager.readBundleFromFile() else { return }
            pendingImportBundle = bundle
            showImportConfirmation = true
        } catch {
            importExportError = error.localizedDescription
        }
    }

    private func performImportApply(_ bundle: ConfigBundle) async {
        isImporting = true
        importExportError = nil
        defer { isImporting = false }

        do {
            let manager = ConfigBundleManager(appState: appState)
            try await manager.applyBundle(bundle)
        } catch {
            importExportError = error.localizedDescription
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
