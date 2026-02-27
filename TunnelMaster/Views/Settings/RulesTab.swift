//
//  RulesTab.swift
//  TunnelMaster
//

import SwiftUI

struct RulesTab: View {
    @Environment(AppState.self) private var appState

    @State private var selectedRuleId: UUID?
    @State private var selectedRuleIds: Set<UUID> = []

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            // Split mode info banner
            if appState.tunnelConfig.mode == .full {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Rules only take effect in Split Tunnel mode.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
                Divider()
            }

            // Default outbound bar
            defaultOutboundBar
            Divider()

            // Main content: list + inspector
            HStack(spacing: 0) {
                RuleListView(
                    selectedRuleId: $selectedRuleId,
                    selectedRuleIds: $selectedRuleIds
                )
                .frame(maxWidth: .infinity)

                if selectedRuleId != nil {
                    Divider()
                    RuleInspectorPanel(ruleId: selectedRuleId!)
                        .frame(width: 260)
                }
            }
        }
        .onChange(of: appState.tunnelConfig) { _, _ in
            appState.saveTunnelConfig()
        }
    }

    // MARK: - Default Outbound Bar

    private var defaultOutboundBar: some View {
        @Bindable var state = appState

        return HStack(spacing: 8) {
            Text("Unmatched traffic:")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("", selection: $state.tunnelConfig.finalOutbound) {
                ForEach(RuleOutbound.allCases) { outbound in
                    Text(outbound.displayName).tag(outbound)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            .labelsHidden()

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
