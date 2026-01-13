//
//  ImportSheet.swift
//  TunnelMaster
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var selectedTab = 0
    @State private var configText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importedCount = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Config")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Tab selector
            Picker("Import Method", selection: $selectedTab) {
                Text("Paste").tag(0)
                Text("File").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            Group {
                switch selectedTab {
                case 0:
                    pasteTab
                case 1:
                    fileTab
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Error/Success message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                }
                .padding()
            } else if importedCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Imported \(importedCount) service(s)")
                        .foregroundStyle(.green)
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Import") {
                    Task {
                        await importFromText()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(configText.isEmpty || isImporting)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private var pasteTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your config (sing-box, Clash, V2Ray, or proxy URI):")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $configText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .border(Color.secondary.opacity(0.3))
                .padding(.horizontal)

            HStack {
                Button("Paste from Clipboard") {
                    if let clipboard = NSPasteboard.general.string(forType: .string) {
                        configText = clipboard
                    }
                }
                .buttonStyle(.link)

                Spacer()

                if isImporting {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private var fileTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Drop a config file here or click to browse")
                .foregroundStyle(.secondary)

            Button("Choose File...") {
                selectFile()
            }
            .buttonStyle(.borderedProminent)

            Text("Supported: .json, .yaml, .yml, .txt")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.05))
        .border(Color.secondary.opacity(0.3), width: 1)
        .padding()
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }

    // MARK: - Actions

    private func importFromText() async {
        guard !configText.isEmpty else { return }

        isImporting = true
        errorMessage = nil
        importedCount = 0

        do {
            let services = try await ImportService.shared.importConfig(text: configText)

            if services.isEmpty {
                throw ImportError.noServicesFound
            }

            await MainActor.run {
                for service in services {
                    appState.addService(service)
                }
                importedCount = services.count
                configText = ""

                // Auto-dismiss after success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isImporting = false
        }
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.json,
            UTType.yaml,
            UTType.plainText,
            UTType(filenameExtension: "yml") ?? .yaml
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await importFromFile(url)
            }
        }
    }

    private func importFromFile(_ url: URL) async {
        isImporting = true
        errorMessage = nil
        importedCount = 0

        do {
            let services = try await ImportService.shared.importConfig(from: url)

            if services.isEmpty {
                throw ImportError.noServicesFound
            }

            await MainActor.run {
                for service in services {
                    appState.addService(service)
                }
                importedCount = services.count

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isImporting = false
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                Task {
                    await importFromFile(url)
                }
            }
        }
    }
}
