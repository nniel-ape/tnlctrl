//
//  PresetApplyConfirmationSheet.swift
//  TunnelMaster
//
//  Preview and confirm preset application with strategy selection.
//

import SwiftUI

struct PresetApplyConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let preset: RulePreset
    let strategy: ApplyStrategy

    enum ApplyStrategy: String, CaseIterable {
        case append = "Append"
        case replace = "Replace All"
        case merge = "Merge"

        var description: String {
            switch self {
            case .append: "Add new rules from preset, skip duplicates"
            case .replace: "Remove all existing rules and use only preset rules"
            case .merge: "Add new rules and update existing matching rules"
            }
        }

        var icon: String {
            switch self {
            case .append: "plus.circle"
            case .replace: "arrow.triangle.2.circlepath"
            case .merge: "arrow.merge"
            }
        }

        var color: Color {
            switch self {
            case .append: .blue
            case .replace: .orange
            case .merge: .purple
            }
        }
    }

    struct ChangePreview: Identifiable {
        let id = UUID()
        let action: ChangeAction
        let rule: RoutingRule

        enum ChangeAction: String {
            case add = "Add"
            case update = "Update"
            case skip = "Skip"
            case delete = "Delete"

            var icon: String {
                switch self {
                case .add: "plus.circle.fill"
                case .update: "arrow.triangle.2.circlepath"
                case .skip: "minus.circle"
                case .delete: "trash.fill"
                }
            }

            var color: Color {
                switch self {
                case .add: .green
                case .update: .orange
                case .skip: .gray
                case .delete: .red
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Strategy info
                HStack(spacing: 12) {
                    Image(systemName: strategy.icon)
                        .font(.title2)
                        .foregroundStyle(strategy.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(strategy.rawValue)
                            .font(.headline)
                        Text(strategy.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.quaternary)

                // Summary
                HStack(spacing: 20) {
                    summaryItem(
                        label: "New Rules",
                        count: newRulesCount,
                        color: .green
                    )
                    summaryItem(
                        label: "Updated",
                        count: updatedCount,
                        color: .orange
                    )
                    summaryItem(
                        label: "Skipped",
                        count: skippedCount,
                        color: .gray
                    )
                    if strategy == .replace {
                        summaryItem(
                            label: "Deleted",
                            count: deletedCount,
                            color: .red
                        )
                    }
                }
                .padding()

                Divider()

                // Changes preview
                List {
                    ForEach(previewChanges) { change in
                        changeRow(change)
                    }
                }
                .listStyle(.inset)
            }
            .frame(width: 600, height: 500)
            .navigationTitle("Apply \(preset.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyPreset()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Summary Item

    private func summaryItem(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Change Row

    private func changeRow(_ change: ChangePreview) -> some View {
        HStack(spacing: 12) {
            Image(systemName: change.action.icon)
                .foregroundStyle(change.action.color)
                .frame(width: 20)

            Image(systemName: change.rule.type.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(change.rule.value)
                    .font(.body)
                Text("\(change.rule.type.displayName) → \(change.rule.outbound.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(change.action.rawValue)
                .font(.caption)
                .foregroundStyle(change.action.color)
        }
    }

    // MARK: - Preview Calculation

    private var previewChanges: [ChangePreview] {
        var changes: [ChangePreview] = []

        switch strategy {
        case .append:
            // Show which rules will be added and which skipped
            for rule in preset.rules {
                let exists = appState.tunnelConfig.rules.contains {
                    $0.type == rule.type && $0.value == rule.value
                }
                changes.append(ChangePreview(
                    action: exists ? .skip : .add,
                    rule: rule
                ))
            }

        case .replace:
            // Show all existing rules as deleted
            for rule in appState.tunnelConfig.rules {
                changes.append(ChangePreview(action: .delete, rule: rule))
            }
            // Show all preset rules as added
            for rule in preset.rules {
                changes.append(ChangePreview(action: .add, rule: rule))
            }

        case .merge:
            // Show which rules will be added and which updated
            for rule in preset.rules {
                if let existing = appState.tunnelConfig.rules.first(where: {
                    $0.type == rule.type && $0.value == rule.value
                }) {
                    // Will update if outbound differs
                    changes.append(ChangePreview(
                        action: existing.outbound == rule.outbound ? .skip : .update,
                        rule: rule
                    ))
                } else {
                    changes.append(ChangePreview(action: .add, rule: rule))
                }
            }
        }

        return changes
    }

    private var newRulesCount: Int {
        previewChanges.filter { $0.action == .add }.count
    }

    private var updatedCount: Int {
        previewChanges.filter { $0.action == .update }.count
    }

    private var skippedCount: Int {
        previewChanges.filter { $0.action == .skip }.count
    }

    private var deletedCount: Int {
        previewChanges.filter { $0.action == .delete }.count
    }

    // MARK: - Apply Logic

    private func applyPreset() {
        switch strategy {
        case .append:
            // Add only non-duplicate rules
            for rule in preset.rules
                where !appState.tunnelConfig.rules.contains(where: { $0.type == rule.type && $0.value == rule.value }) {
                appState.tunnelConfig.rules.append(rule)
            }

        case .replace:
            // Clear all and add preset rules
            appState.tunnelConfig.rules = preset.rules

        case .merge:
            // Add new, update existing
            for rule in preset.rules {
                if let index = appState.tunnelConfig.rules.firstIndex(where: {
                    $0.type == rule.type && $0.value == rule.value
                }) {
                    // Update existing rule (keep ID, update outbound/note)
                    appState.tunnelConfig.rules[index].outbound = rule.outbound
                    appState.tunnelConfig.rules[index].note = rule.note
                    appState.tunnelConfig.rules[index].lastModified = Date()
                } else {
                    // Add new rule
                    appState.tunnelConfig.rules.append(rule)
                }
            }
        }
    }
}
