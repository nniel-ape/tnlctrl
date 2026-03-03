//
//  GroupHeaderRow.swift
//  tnl_ctrl
//
//  Collapsible group header row displayed inline in the rule list.
//

import SwiftUI

struct GroupHeaderRow: View {
    let group: RuleGroup
    let ruleCount: Int
    let isEnabled: Bool
    let onToggleEnabled: () -> Void
    let onSetOutbound: (RuleOutbound) -> Void
    let onToggleExpanded: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Disclosure chevron
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(group.isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: group.isExpanded)
                .frame(width: 12)
                .onTapGesture { onToggleExpanded() }

            // Group icon
            Image(systemName: group.icon)
                .font(.caption)
                .foregroundStyle(group.color.swiftUIColor)

            // Group name
            Text(group.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 4)

            // Enable/disable toggle
            Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in onToggleEnabled() }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()

            // Rule count badge
            Text("\(ruleCount)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
        }
        .opacity(isEnabled ? 1 : 0.5)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onToggleEnabled()
            } label: {
                Label(
                    isEnabled ? "Disable All Rules" : "Enable All Rules",
                    systemImage: isEnabled ? "eye.slash" : "eye"
                )
            }

            Menu("Set Outbound") {
                ForEach(RuleOutbound.allCases) { outbound in
                    Button {
                        onSetOutbound(outbound)
                    } label: {
                        Label(outbound.displayName, systemImage: outbound.systemImage)
                    }
                }
            }

            Button {
                onToggleExpanded()
            } label: {
                Label(
                    group.isExpanded ? "Collapse" : "Expand",
                    systemImage: group.isExpanded ? "chevron.up" : "chevron.down"
                )
            }

            Divider()

            Button("Delete Group", role: .destructive, action: onDelete)
        }
    }
}
