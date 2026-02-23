//
//  RuleItemRow.swift
//  TunnelMaster
//
//  Individual rule row with checkbox and metadata.
//

import SwiftUI

struct RuleItemRow: View {
    @Binding var rule: RoutingRule
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Enabled checkbox
            Toggle("", isOn: $rule.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)

            // Rule icon
            Image(systemName: rule.type.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            // Rule details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.value)
                        .font(.body)

                    // Tags
                    if !rule.tags.isEmpty {
                        ForEach(rule.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 6) {
                    Text(rule.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(rule.outbound.displayName)
                        .font(.caption)
                        .foregroundStyle(rule.outbound.color)
                }

                // Note
                if let note = rule.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Note indicator
            if let note = rule.note, !note.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(rule.isEnabled ? 1.0 : 0.5)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                rule.isEnabled.toggle()
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
