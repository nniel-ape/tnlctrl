//
//  PresetCreateSheet.swift
//  TunnelMaster
//
//  Create or edit a custom preset.
//

import SwiftUI

struct PresetCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var color: PresetColor
    @State private var selectedRules: Set<UUID>

    private let existingPreset: RulePreset?
    private let onSave: (RulePreset) -> Void

    init(existingPreset: RulePreset? = nil, onSave: @escaping (RulePreset) -> Void) {
        self.existingPreset = existingPreset
        self.onSave = onSave

        _name = State(initialValue: existingPreset?.name ?? "")
        _description = State(initialValue: existingPreset?.description ?? "")
        _icon = State(initialValue: existingPreset?.icon ?? "list.bullet.rectangle")
        _color = State(initialValue: existingPreset?.color ?? .blue)
        _selectedRules = State(initialValue: Set(existingPreset?.rules.map(\.id) ?? []))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 480, height: 520)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(colorValue)
            Text(existingPreset == nil ? "Create Preset" : "Edit Preset")
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
        Form {
            // Basic info
            Section("Preset Info") {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
            }

            // Appearance
            Section("Appearance") {
                // Icon picker
                iconPicker

                // Color picker
                Picker("Color", selection: $color) {
                    ForEach(PresetColor.allCases) { c in
                        HStack {
                            Circle()
                                .fill(colorFor(c))
                                .frame(width: 12, height: 12)
                            Text(c.displayName)
                        }
                        .tag(c)
                    }
                }
            }

            // Rules selection
            Section {
                if appState.tunnelConfig.rules.isEmpty {
                    Text("No rules to include. Add rules first in the Tunnel tab.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Select rules to include in this preset:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(appState.tunnelConfig.rules) { rule in
                        ruleToggle(rule)
                    }
                }
            } header: {
                HStack {
                    Text("Rules")
                    Spacer()
                    Text("\(selectedRules.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var iconPicker: some View {
        let icons = [
            "list.bullet.rectangle", "shield", "globe", "network",
            "play.tv", "person.2", "gamecontroller", "cart",
            "briefcase", "house", "building.2", "airplane",
            "cloud", "lock.shield", "bolt.shield", "nosign"
        ]

        return VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 8) {
                ForEach(icons, id: \.self) { iconName in
                    Button {
                        icon = iconName
                    } label: {
                        Image(systemName: iconName)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(icon == iconName ? colorValue.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func ruleToggle(_ rule: RoutingRule) -> some View {
        Toggle(isOn: Binding(
            get: { selectedRules.contains(rule.id) },
            set: { isOn in
                if isOn {
                    selectedRules.insert(rule.id)
                } else {
                    selectedRules.remove(rule.id)
                }
            }
        )) {
            HStack {
                Text(rule.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor(for: rule).opacity(0.2))
                    .foregroundStyle(badgeColor(for: rule))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(rule.value)
                    .lineLimit(1)

                Spacer()

                Image(systemName: rule.outbound.systemImage)
                    .foregroundStyle(outboundColor(for: rule))
                    .font(.caption)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            // Quick select buttons
            if !appState.tunnelConfig.rules.isEmpty {
                Button("Select All") {
                    selectedRules = Set(appState.tunnelConfig.rules.map(\.id))
                }

                Button("Select None") {
                    selectedRules.removeAll()
                }
            }

            Button("Save") {
                save()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding()
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedRules.isEmpty
    }

    private var colorValue: Color {
        colorFor(color)
    }

    private func colorFor(_ c: PresetColor) -> Color {
        switch c {
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

    private func badgeColor(for rule: RoutingRule) -> Color {
        switch rule.type {
        case .domain, .domainSuffix, .domainKeyword: .purple
        case .ipCidr: .orange
        case .geoip, .geosite: .teal
        case .processName, .processPath: .gray
        }
    }

    private func outboundColor(for rule: RoutingRule) -> Color {
        switch rule.outbound {
        case .direct: .green
        case .proxy: .blue
        case .block: .red
        }
    }

    private func save() {
        let rules = appState.tunnelConfig.rules.filter { selectedRules.contains($0.id) }

        let preset = RulePreset(
            id: existingPreset?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            rules: rules,
            isBuiltIn: false,
            icon: icon,
            color: color
        )

        onSave(preset)
        dismiss()
    }
}
