//
//  GroupInspectorPanel.swift
//  tnl_ctrl
//
//  Inspector panel for editing a selected rule group.
//

import SwiftUI

struct GroupInspectorPanel: View {
    @Environment(AppState.self) private var appState
    let groupId: UUID

    private let iconOptions = [
        "folder", "folder.fill", "star", "star.fill",
        "shield", "shield.fill", "lock", "lock.fill",
        "globe", "globe.americas", "network", "wifi",
        "bolt", "bolt.fill", "flame", "flame.fill",
        "play.circle", "play.circle.fill", "tv", "desktopcomputer",
        "person.2", "person.fill", "eye", "eye.slash",
        "music.note", "gamecontroller", "film", "camera",
        "doc", "book", "bookmark", "tag",
        "flag", "flag.fill", "bell", "bell.fill",
        "heart", "heart.fill", "hand.raised", "hand.raised.fill",
        "cloud", "cloud.fill", "sun.max", "moon",
        "leaf", "leaf.fill", "drop", "wind",
    ]

    @State private var showIconPicker = false

    private let iconGridColumns = Array(repeating: GridItem(.fixed(28), spacing: 4), count: 6)

    private var groupIndex: Int? {
        appState.tunnelConfig.groups.firstIndex(where: { $0.id == groupId })
    }

    var body: some View {
        @Bindable var state = appState

        if let index = groupIndex {
            let group = appState.tunnelConfig.groups[index]

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(group: group, index: index)
                    Divider()
                    appearanceSection(group: group, index: index)
                    Divider()
                    descriptionSection(index: index)
                    Divider()
                    infoSection(group: group)
                    Divider()
                    outboundSection(group: group)
                    Divider()
                    actionsSection(group: group)

                    Spacer()
                }
                .padding(16)
            }
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "sidebar.right",
                description: Text("Select a group to inspect")
            )
        }
    }

    // MARK: - Header

    private func header(group: RuleGroup, index: Int) -> some View {
        @Bindable var state = appState
        let isEnabled = appState.tunnelConfig.allRulesEnabled(in: groupId)

        return HStack(spacing: 8) {
            Image(systemName: group.icon)
                .font(.title3)
                .foregroundStyle(group.color.swiftUIColor)

            TextField("Group Name", text: $state.tunnelConfig.groups[index].name)
                .font(.headline)
                .textFieldStyle(.plain)

            Spacer()

            Toggle("Enabled", isOn: Binding(
                get: { isEnabled },
                set: { appState.tunnelConfig.setGroupEnabled(groupId, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
        }
    }

    // MARK: - Appearance

    private func appearanceSection(group: RuleGroup, index: Int) -> some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: 6) {
            Text("APPEARANCE")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            // Icon picker
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Icon")
                        .font(.callout)
                    Spacer()
                    Button {
                        showIconPicker.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: group.icon)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showIconPicker) {
                        iconGrid(group: group, index: index)
                    }
                }
            }

            // Color picker — horizontal swatches
            LabeledContent("Color") {
                HStack(spacing: 4) {
                    ForEach(GroupColor.allCases, id: \.self) { color in
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 16, height: 16)
                            .overlay {
                                if group.color == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture {
                                appState.tunnelConfig.groups[index].color = color
                            }
                    }
                }
            }
            .font(.callout)
        }
    }

    // MARK: - Icon Grid

    private func iconGrid(group: RuleGroup, index: Int) -> some View {
        LazyVGrid(columns: iconGridColumns, spacing: 4) {
            ForEach(iconOptions, id: \.self) { option in
                Button {
                    appState.tunnelConfig.groups[index].icon = option
                    showIconPicker = false
                } label: {
                    Image(systemName: option)
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .background(group.icon == option ? group.color.swiftUIColor.opacity(0.2) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 200)
    }

    // MARK: - Description

    private func descriptionSection(index: Int) -> some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: 6) {
            Text("DESCRIPTION")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            TextField("Optional description", text: $state.tunnelConfig.groups[index].description)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }

    // MARK: - Info

    private func infoSection(group: RuleGroup) -> some View {
        let ruleCount = appState.tunnelConfig.rules(in: group.id).count

        return VStack(alignment: .leading, spacing: 4) {
            Text("INFO")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            LabeledContent("Rules") {
                Text("\(ruleCount)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.callout)
        }
    }

    // MARK: - Bulk Outbound

    private func outboundSection(group: RuleGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SET ALL OUTBOUND")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Picker("", selection: Binding(
                get: {
                    let outbounds = Set(appState.tunnelConfig.rules(in: group.id).map(\.outbound))
                    return outbounds.count == 1 ? outbounds.first : nil
                },
                set: { newValue in
                    if let outbound = newValue {
                        appState.tunnelConfig.setGroupOutbound(group.id, outbound: outbound)
                    }
                }
            )) {
                ForEach(RuleOutbound.allCases) { outbound in
                    Text(outbound.displayName).tag(RuleOutbound?.some(outbound))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Actions

    private func actionsSection(group: RuleGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIONS")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Button {
                let newGroup = RuleGroup(
                    name: "\(group.name) Copy",
                    description: group.description,
                    icon: group.icon,
                    color: group.color,
                    position: appState.tunnelConfig.groups.count
                )
                appState.tunnelConfig.groups.append(newGroup)
            } label: {
                Label("Duplicate Group", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                appState.tunnelConfig.deleteGroup(group.id)
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
