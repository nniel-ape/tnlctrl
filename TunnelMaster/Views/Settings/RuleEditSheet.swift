//
//  RuleEditSheet.swift
//  TunnelMaster
//

import SwiftUI

struct RuleEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var ruleType: RuleType
    @State private var value: String
    @State private var outbound: RuleOutbound

    private let existingRule: RoutingRule?
    private let onSave: (RoutingRule) -> Void

    init(rule: RoutingRule? = nil, onSave: @escaping (RoutingRule) -> Void) {
        self.existingRule = rule
        self.onSave = onSave
        _ruleType = State(initialValue: rule?.type ?? .domain)
        _value = State(initialValue: rule?.value ?? "")
        _outbound = State(initialValue: rule?.outbound ?? .proxy)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingRule == nil ? "Add Rule" : "Edit Rule")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Rule Type") {
                    Picker("Type", selection: $ruleType) {
                        ForEach(RuleType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Text(ruleTypeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Value") {
                    TextField(ruleType.placeholder, text: $value)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Action") {
                    Picker("Outbound", selection: $outbound) {
                        ForEach(RuleOutbound.allCases) { action in
                            Label(action.displayName, systemImage: action.systemImage)
                                .tag(action)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(outboundDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var ruleTypeDescription: String {
        switch ruleType {
        case .processName:
            "Match traffic from apps by process name"
        case .processPath:
            "Match traffic from apps by full executable path"
        case .domain:
            "Match exact domain name"
        case .domainSuffix:
            "Match domain and all subdomains"
        case .domainKeyword:
            "Match domains containing this keyword"
        case .ipCidr:
            "Match IP addresses in CIDR range"
        case .geoip:
            "Match by country code (requires geoip.db)"
        case .geosite:
            "Match by site category (requires geosite.db)"
        }
    }

    private var outboundDescription: String {
        switch outbound {
        case .direct:
            "Bypass the tunnel, connect directly"
        case .proxy:
            "Route through the configured proxy"
        case .block:
            "Block the connection"
        }
    }

    private func save() {
        let rule = RoutingRule(
            id: existingRule?.id ?? UUID(),
            type: ruleType,
            value: value.trimmingCharacters(in: .whitespaces),
            outbound: outbound
        )
        onSave(rule)
        dismiss()
    }
}
