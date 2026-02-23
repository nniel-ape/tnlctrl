//
//  GroupEditorSheet.swift
//  TunnelMaster
//
//  Create or edit a rule group.
//

import SwiftUI

struct GroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let group: RuleGroup? // nil = create, non-nil = edit

    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "folder"
    @State private var selectedColor: GroupColor = .blue

    private let iconOptions = [
        "folder", "star", "play.circle", "shield", "globe",
        "network", "person.2", "tv", "music.note", "gamecontroller"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2 ... 4)
                }

                Section("Appearance") {
                    Picker("Icon", selection: $selectedIcon) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Label {
                                Text(icon)
                            } icon: {
                                Image(systemName: icon)
                            }
                            .tag(icon)
                        }
                    }

                    Picker("Color", selection: $selectedColor) {
                        ForEach(GroupColor.allCases, id: \.self) { color in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(color.swiftUIColor)
                                Text(color.displayName)
                            }
                            .tag(color)
                        }
                    }
                }

                Section("Preview") {
                    HStack {
                        Image(systemName: selectedIcon)
                            .foregroundStyle(selectedColor.swiftUIColor)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Group Name" : name)
                                .font(.headline)
                            if !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 500)
            .navigationTitle(group == nil ? "New Group" : "Edit Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGroup()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let group {
                    name = group.name
                    description = group.description
                    selectedIcon = group.icon
                    selectedColor = group.color
                }
            }
        }
    }

    private func saveGroup() {
        if let group {
            // Edit existing
            if let index = appState.tunnelConfig.groups.firstIndex(where: { $0.id == group.id }) {
                appState.tunnelConfig.groups[index].name = name
                appState.tunnelConfig.groups[index].description = description
                appState.tunnelConfig.groups[index].icon = selectedIcon
                appState.tunnelConfig.groups[index].color = selectedColor
            }
        } else {
            // Create new
            let newGroup = RuleGroup(
                name: name,
                description: description,
                icon: selectedIcon,
                color: selectedColor,
                position: appState.tunnelConfig.groups.count
            )
            appState.tunnelConfig.groups.append(newGroup)
        }
    }
}
