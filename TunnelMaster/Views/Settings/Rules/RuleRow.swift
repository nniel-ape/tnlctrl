//
//  RuleRow.swift
//  TunnelMaster
//
//  Flat, scannable rule row for the list + inspector layout.
//

import SwiftUI

struct RuleRow: View {
    let rule: RoutingRule
    let group: RuleGroup?
    let onToggleEnabled: () -> Void
    let onDelete: () -> Void
    let onSetOutbound: (RuleOutbound) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Group color indicator
            if let group {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(group.color.swiftUIColor)
                    .frame(width: 3, height: 20)
                    .padding(.trailing, 6)
            }

            // Type icon
            Image(systemName: rule.type.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            // Type short name
            Text(rule.type.shortName)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 50, alignment: .leading)
                .padding(.leading, 4)

            // Value
            Text(rule.value)
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            // Note indicator
            if rule.note != nil {
                Image(systemName: "text.bubble")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 6)
            }

            // Outbound badge
            Text(rule.outbound.displayName.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(rule.outbound.color)
        }
        .padding(.vertical, 2)
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
