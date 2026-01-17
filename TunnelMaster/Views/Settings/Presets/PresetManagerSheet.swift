//
//  PresetManagerSheet.swift
//  TunnelMaster
//
//  Manage built-in and custom presets.
//

import SwiftUI
import UniformTypeIdentifiers

struct PresetManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var showingCreateSheet = false
    @State private var showingImportSheet = false
    @State private var editingPreset: RulePreset?
    @State private var exportingPreset: RulePreset?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 500, height: 500)
        .sheet(isPresented: $showingCreateSheet) {
            PresetCreateSheet { preset in
                appState.tunnelConfig.customPresets.append(preset)
            }
        }
        .sheet(item: $editingPreset) { preset in
            PresetCreateSheet(existingPreset: preset) { updated in
                if let index = appState.tunnelConfig.customPresets.firstIndex(where: { $0.id == preset.id }) {
                    appState.tunnelConfig.customPresets[index] = updated
                }
            }
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportingPreset != nil },
                set: { if !$0 { exportingPreset = nil } }
            ),
            document: exportingPreset.map { PresetDocument(preset: $0) },
            contentType: .json,
            defaultFilename: exportingPreset?.name.replacingOccurrences(of: " ", with: "_") ?? "preset"
        ) { result in
            switch result {
            case let .success(url):
                print("Exported preset to: \(url)")
            case let .failure(error):
                print("Export failed: \(error)")
            }
            exportingPreset = nil
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "list.bullet.rectangle")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("Manage Presets")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Built-in presets
                sectionHeader("Built-in Presets")
                ForEach(RulePreset.builtInPresets) { preset in
                    presetRow(preset, isBuiltIn: true)
                }

                // Custom presets
                if !appState.tunnelConfig.customPresets.isEmpty {
                    sectionHeader("Custom Presets")
                    ForEach(appState.tunnelConfig.customPresets) { preset in
                        presetRow(preset, isBuiltIn: false)
                    }
                }
            }
            .padding()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func presetRow(_ preset: RulePreset, isBuiltIn: Bool) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: preset.icon)
                .font(.title2)
                .foregroundStyle(colorForPreset(preset))
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .fontWeight(.medium)
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(preset.rules.count) rules")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                // Apply button
                Button {
                    applyPreset(preset)
                } label: {
                    Label("Apply", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                // More menu
                Menu {
                    Button {
                        applyPreset(preset)
                    } label: {
                        Label("Apply Rules", systemImage: "plus.circle")
                    }

                    Button {
                        exportingPreset = preset
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

                    if !isBuiltIn {
                        Divider()

                        Button {
                            editingPreset = preset
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            duplicatePreset(preset)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button(role: .destructive) {
                            deletePreset(preset)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                showingImportSheet = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Spacer()

            Button {
                showingCreateSheet = true
            } label: {
                Label("Create Preset", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Actions

    private func applyPreset(_ preset: RulePreset) {
        for rule in preset.rules {
            let exists = appState.tunnelConfig.rules.contains {
                $0.type == rule.type && $0.value.lowercased() == rule.value.lowercased()
            }
            if !exists {
                appState.tunnelConfig.rules.append(rule)
            }
        }
    }

    private func duplicatePreset(_ preset: RulePreset) {
        var newPreset = preset
        newPreset = RulePreset(
            name: "\(preset.name) Copy",
            description: preset.description,
            rules: preset.rules,
            isBuiltIn: false,
            icon: preset.icon,
            color: preset.color
        )
        appState.tunnelConfig.customPresets.append(newPreset)
    }

    private func deletePreset(_ preset: RulePreset) {
        appState.tunnelConfig.customPresets.removeAll { $0.id == preset.id }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            do {
                let preset = try RulePresetExporter.importPreset(from: url)
                appState.tunnelConfig.customPresets.append(preset)
            } catch {
                print("Import failed: \(error)")
            }
        case let .failure(error):
            print("Import failed: \(error)")
        }
    }

    private func colorForPreset(_ preset: RulePreset) -> Color {
        switch preset.color {
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        case .gray: .gray
        }
    }
}

// MARK: - Preset Document for Export

struct PresetDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let preset: RulePreset

    init(preset: RulePreset) {
        self.preset = preset
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.preset = try RulePresetExporter.importPreset(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try RulePresetExporter.export(preset)
        return FileWrapper(regularFileWithContents: data)
    }
}
