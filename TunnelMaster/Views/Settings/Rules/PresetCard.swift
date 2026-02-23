//
//  PresetCard.swift
//  TunnelMaster
//
//  Compact toggleable preset card for quick rule application.
//

import SwiftUI

struct PresetCard: View {
    let preset: RulePreset
    let isApplied: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: preset.icon)
                    .font(.caption)
                    .foregroundStyle(isApplied ? .white : presetColor)
                    .frame(width: 24, height: 24)
                    .background(isApplied ? presetColor : presetColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Name + count
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("\(preset.rules.count) rules")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Checkmark
                Image(systemName: isApplied ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isApplied ? presetColor : Color.gray.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var presetColor: Color {
        switch preset.color {
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        case .gray: .gray
        }
    }
}
