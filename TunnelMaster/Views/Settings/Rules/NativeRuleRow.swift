//
//  NativeRuleRow.swift
//  TunnelMaster
//
//  Native-style rule row with switch toggle and outbound badge.
//

import SwiftUI

struct NativeRuleRow: View {
    let rule: RoutingRule
    let onToggleEnabled: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Toggle(isOn: .init(get: { rule.isEnabled }, set: { _ in onToggleEnabled() })) {
            HStack(spacing: 8) {
                // Rule value as primary text
                Text(rule.value)
                    .font(.body.monospaced())
                    .lineLimit(1)

                Spacer()

                // Outbound capsule badge
                Text(rule.outbound.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(rule.outbound.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(rule.outbound.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .opacity(rule.isEnabled ? 1.0 : 0.6)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onToggleEnabled()
            } label: {
                Label(
                    rule.isEnabled ? "Disable" : "Enable",
                    systemImage: rule.isEnabled ? "eye.slash" : "eye"
                )
            }

            Divider()

            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
