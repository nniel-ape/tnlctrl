//
//  RuleGroupHeader.swift
//  TunnelMaster
//
//  Header view for collapsible rule groups.
//

import SwiftUI

struct RuleGroupHeader: View {
    @Binding var group: RuleGroup
    let ruleCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Button {
                group.isExpanded.toggle()
            } label: {
                Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: group.icon)
                .foregroundStyle(group.color.swiftUIColor)

            Text(group.name)
                .font(.headline)

            if !group.description.isEmpty {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text(group.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(ruleCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
