//
//  PresetRow.swift
//  TunnelMaster
//

import SwiftUI

struct PresetRow: View {
    let preset: TunnelPreset
    var isActive = false
    var serviceName: String?
    var chainHops = 0
    var enabledRuleCount = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .lineLimit(1)
                    .fontWeight(isActive ? .medium : .regular)
                    .foregroundStyle(isActive ? .primary : .secondary)

                if !summaryParts.isEmpty {
                    Text(summaryParts.joined(separator: " \u{00B7} "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tint)
            }

            Text(preset.mode.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundColor(isActive ? .accentColor : .secondary)
        }
        .contentShape(Rectangle())
    }

    private var summaryParts: [String] {
        var parts: [String] = []
        if let name = serviceName {
            parts.append(name)
        }
        if chainHops >= 2 {
            parts.append("\(chainHops)-hop chain")
        }
        if enabledRuleCount > 0 {
            parts.append("\(enabledRuleCount) rule\(enabledRuleCount == 1 ? "" : "s")")
        }
        return parts
    }
}
