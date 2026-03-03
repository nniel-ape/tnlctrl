//
//  ValidationDisplayView.swift
//  tnl_ctrl
//

import SwiftUI

/// Displays tunnel configuration validation results with color-coded severity indicators
struct ValidationDisplayView: View {
    let result: TunnelConfigValidator.ValidationResult

    var body: some View {
        Section {
            if result.isValid, !result.hasWarnings {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Configuration valid")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(result.issues) { issue in
                    HStack(alignment: .top) {
                        Image(systemName: issue.icon)
                            .foregroundStyle(issue.severity == .error ? .red : (issue.severity == .warning ? .orange : .blue))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.message)
                                .font(.callout)
                            if let suggestion = issue.suggestion {
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Label("Status", systemImage: result.isValid ? "checkmark.shield" : "exclamationmark.shield")
        }
    }
}
