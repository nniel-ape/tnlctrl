//
//  RuleRow.swift
//  tnl_ctrl
//
//  Flat, scannable rule row for the list + inspector layout.
//

import SwiftUI

struct RuleRow: View {
    let rule: RoutingRule
    let onToggleEnabled: () -> Void
    let onDelete: () -> Void
    let onSetOutbound: (RuleOutbound) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Type icon
            Image(systemName: rule.type.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            // Value
            Text(rule.value)
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.leading, 6)

            Spacer(minLength: 8)

            // Note indicator
            if rule.note != nil {
                Image(systemName: "text.bubble")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 6)
            }

            // Type short name
            Text(rule.type.shortName)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 8)

            // Outbound badge
            Text(rule.outbound.displayName.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(rule.outbound.color)
                .padding(.trailing, 8)

            // Enable/disable toggle
            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in onToggleEnabled() }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1.0 : 0.4)
        .contextMenu {
            Button {
                onToggleEnabled()
            } label: {
                Label(
                    rule.isEnabled ? "Disable" : "Enable",
                    systemImage: rule.isEnabled ? "eye.slash" : "eye"
                )
            }

            Divider()

            Menu("Set Outbound") {
                ForEach(RuleOutbound.allCases) { outbound in
                    Button {
                        onSetOutbound(outbound)
                    } label: {
                        Label(outbound.displayName, systemImage: outbound.systemImage)
                    }
                }
            }

            Divider()

            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
