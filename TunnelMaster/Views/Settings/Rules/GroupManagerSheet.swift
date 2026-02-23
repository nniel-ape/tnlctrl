//
//  GroupManagerSheet.swift
//  TunnelMaster
//
//  Manage all rule groups.
//

import SwiftUI

struct GroupManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var activeSheet: GroupEditorDestination?

    enum GroupEditorDestination: Identifiable {
        case create
        case edit(RuleGroup)

        var id: String {
            switch self {
            case .create: return "create"
            case let .edit(group): return "edit-\(group.id.uuidString)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if appState.tunnelConfig.groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "folder.badge.plus",
                        description: Text("Create groups to organize your routing rules")
                    )
                } else {
                    List {
                        ForEach(appState.tunnelConfig.sortedGroups) { group in
                            groupRow(group)
                        }
                        .onMove { from, to in
                            appState.tunnelConfig.groups.move(fromOffsets: from, toOffset: to)
                            updateGroupPositions()
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
                        activeSheet = .create
                    } label: {
                        Label("Create Group", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $activeSheet) { destination in
                switch destination {
                case .create:
                    GroupEditorSheet(group: nil)
                case let .edit(group):
                    GroupEditorSheet(group: group)
                }
            }
        }
    }

    private func groupRow(_ group: RuleGroup) -> some View {
        let ruleCount = appState.tunnelConfig.rules(in: group.id).count

        return HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Icon
            Image(systemName: group.icon)
                .foregroundStyle(group.color.swiftUIColor)
                .font(.title2)
                .frame(width: 32)

            // Info
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

            // Rule count
            Text("\(ruleCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) {
                deleteGroup(group)
            }
        }
        .contextMenu {
            Button {
                activeSheet = .edit(group)
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

    private func deleteGroup(_ group: RuleGroup) {
        // Move rules back to ungrouped
        for i in 0 ..< appState.tunnelConfig.rules.count {
            if appState.tunnelConfig.rules[i].groupId == group.id {
                appState.tunnelConfig.rules[i].groupId = nil
            }
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
