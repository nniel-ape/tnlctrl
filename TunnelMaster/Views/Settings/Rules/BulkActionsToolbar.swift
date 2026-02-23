//
//  BulkActionsToolbar.swift
//  TunnelMaster
//
//  Toolbar for bulk rule operations.
//

import SwiftUI

struct BulkActionsToolbar: View {
    let selectedCount: Int
    let groups: [RuleGroup]
    let onEnable: () -> Void
    let onDisable: () -> Void
    let onChangeOutbound: (RuleOutbound) -> Void
    let onMoveToGroup: (UUID?) -> Void
    let onAddTag: (String) -> Void
    let onDelete: () -> Void
    let onClearSelection: () -> Void

    @State private var newTag = ""

    var body: some View {
        HStack(spacing: 12) {
            Text("\(selectedCount) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 20)

            Button("Enable", action: onEnable)
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button("Disable", action: onDisable)
                .buttonStyle(.bordered)
                .controlSize(.small)

            Menu {
                Button("Ungrouped") { onMoveToGroup(nil) }
                if !groups.isEmpty {
                    Divider()
                    ForEach(groups.sorted(by: { $0.position < $1.position })) { group in
                        Button {
                            onMoveToGroup(group.id)
                        } label: {
                            Label(group.name, systemImage: group.icon)
                        }
                    }
                }
            } label: {
                Label("Move to", systemImage: "folder")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                Button {
                    onChangeOutbound(.direct)
                } label: {
                    Label("Direct", systemImage: RuleOutbound.direct.systemImage)
                }
                Button {
                    onChangeOutbound(.proxy)
                } label: {
                    Label("Proxy", systemImage: RuleOutbound.proxy.systemImage)
                }
                Button {
                    onChangeOutbound(.block)
                } label: {
                    Label("Block", systemImage: RuleOutbound.block.systemImage)
                }
            } label: {
                Label("Set Outbound", systemImage: "arrow.triangle.branch")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                HStack {
                    TextField("Tag name", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)

                    Button("Add") {
                        if !newTag.isEmpty {
                            onAddTag(newTag)
                            newTag = ""
                        }
                    }
                    .disabled(newTag.isEmpty)
                }
                .padding(8)
            } label: {
                Label("Add Tag", systemImage: "tag")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Button("Delete", role: .destructive, action: onDelete)
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button("Clear", action: onClearSelection)
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
