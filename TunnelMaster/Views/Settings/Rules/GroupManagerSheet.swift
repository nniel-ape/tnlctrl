//
//  GroupManagerSheet.swift
//  TunnelMaster
//
//  Manage all rule groups with inline editing.
//

import SwiftUI

struct GroupManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var editingGroupId: UUID?
    @State private var editName = ""
    @State private var editIcon = "folder"
    @State private var editColor: GroupColor = .blue

    @State private var isCreating = false
    @State private var newName = ""
    @State private var newIcon = "folder"
    @State private var newColor: GroupColor = .blue

    private let iconOptions = [
        "folder", "star", "play.circle", "shield", "globe",
        "network", "person.2", "tv", "music.note", "gamecontroller",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if appState.tunnelConfig.groups.isEmpty, !isCreating {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "folder.badge.plus",
                        description: Text("Create groups to organize your routing rules")
                    )
                } else {
                    List {
                        ForEach(appState.tunnelConfig.sortedGroups) { group in
                            if editingGroupId == group.id {
                                editRow(for: group)
                            } else {
                                groupRow(group)
                            }
                        }
                        .onMove { from, to in
                            appState.tunnelConfig.groups.move(fromOffsets: from, toOffset: to)
                            updateGroupPositions()
                        }

                        if isCreating {
                            createRow
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(width: 500, height: 400)
            .navigationTitle("Manage Groups")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        beginCreate()
                    } label: {
                        Label("Create Group", systemImage: "plus")
                    }
                    .disabled(isCreating || editingGroupId != nil)
                }
            }
        }
    }

    // MARK: - Display Row

    private func groupRow(_ group: RuleGroup) -> some View {
        let ruleCount = appState.tunnelConfig.rules(in: group.id).count

        return HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Image(systemName: group.icon)
                .foregroundStyle(group.color.swiftUIColor)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .fontWeight(.medium)
                if !group.description.isEmpty {
                    Text(group.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(ruleCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .contextMenu {
            Button {
                beginEdit(group)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                duplicateGroup(group)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }

            Divider()

            Button("Delete", role: .destructive) {
                deleteGroup(group)
            }
        }
    }

    // MARK: - Inline Edit / Create Rows

    private func editRow(for group: RuleGroup) -> some View {
        GroupFormRow(
            name: $editName,
            icon: $editIcon,
            color: $editColor,
            iconOptions: iconOptions,
            saveLabel: "Save",
            isSaveDisabled: editName.trimmingCharacters(in: .whitespaces).isEmpty,
            onCancel: { editingGroupId = nil },
            onSave: { saveEdit(group) }
        )
    }

    private var createRow: some View {
        GroupFormRow(
            name: $newName,
            icon: $newIcon,
            color: $newColor,
            iconOptions: iconOptions,
            saveLabel: "Create",
            isSaveDisabled: newName.trimmingCharacters(in: .whitespaces).isEmpty,
            onCancel: { isCreating = false },
            onSave: { saveNew() }
        )
    }

    // MARK: - Actions

    private func beginEdit(_ group: RuleGroup) {
        isCreating = false
        editingGroupId = group.id
        editName = group.name
        editIcon = group.icon
        editColor = group.color
    }

    private func saveEdit(_ group: RuleGroup) {
        if let index = appState.tunnelConfig.groups.firstIndex(where: { $0.id == group.id }) {
            appState.tunnelConfig.groups[index].name = editName.trimmingCharacters(in: .whitespaces)
            appState.tunnelConfig.groups[index].icon = editIcon
            appState.tunnelConfig.groups[index].color = editColor
        }
        editingGroupId = nil
    }

    private func beginCreate() {
        editingGroupId = nil
        newName = ""
        newIcon = "folder"
        newColor = .blue
        isCreating = true
    }

    private func saveNew() {
        let group = RuleGroup(
            name: newName.trimmingCharacters(in: .whitespaces),
            icon: newIcon,
            color: newColor,
            position: appState.tunnelConfig.groups.count
        )
        appState.tunnelConfig.groups.append(group)
        isCreating = false
    }

    private func deleteGroup(_ group: RuleGroup) {
        for i in 0 ..< appState.tunnelConfig.rules.count where appState.tunnelConfig.rules[i].groupId == group.id {
            appState.tunnelConfig.rules[i].groupId = nil
        }
        appState.tunnelConfig.groups.removeAll { $0.id == group.id }
        updateGroupPositions()
    }

    private func duplicateGroup(_ group: RuleGroup) {
        let newGroup = RuleGroup(
            name: "\(group.name) Copy",
            description: group.description,
            icon: group.icon,
            color: group.color,
            position: appState.tunnelConfig.groups.count
        )
        appState.tunnelConfig.groups.append(newGroup)
    }

    private func updateGroupPositions() {
        for (index, group) in appState.tunnelConfig.groups.enumerated() {
            if let idx = appState.tunnelConfig.groups.firstIndex(where: { $0.id == group.id }) {
                appState.tunnelConfig.groups[idx].position = index
            }
        }
    }
}

// MARK: - Group Form Row

private struct GroupFormRow: View {
    @Binding var name: String
    @Binding var icon: String
    @Binding var color: GroupColor

    let iconOptions: [String]
    let saveLabel: String
    let isSaveDisabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(iconOptions, id: \.self) { option in
                        Button {
                            icon = option
                        } label: {
                            Label(option, systemImage: option)
                        }
                    }
                } label: {
                    Image(systemName: icon)
                        .foregroundStyle(color.swiftUIColor)
                        .font(.title2)
                        .frame(width: 32)
                }

                TextField("Group name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 8) {
                Picker("Color", selection: $color) {
                    ForEach(GroupColor.allCases, id: \.self) { groupColor in
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(groupColor.swiftUIColor)
                            Text(groupColor.displayName)
                        }
                        .tag(groupColor)
                    }
                }
                .labelsHidden()

                Spacer()

                Button("Cancel", action: onCancel)
                Button(saveLabel, action: onSave)
                    .disabled(isSaveDisabled)
            }
        }
        .padding(.vertical, 4)
    }
}
