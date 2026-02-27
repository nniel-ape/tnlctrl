//
//  RulesTab.swift
//  TunnelMaster
//

import SwiftUI

enum RuleListSelection: Hashable {
    case rule(UUID)
    case group(UUID)
}

struct RulesTab: View {
    @Environment(AppState.self) private var appState

    @State private var selection: RuleListSelection?
    @State private var selectedItems: Set<RuleListSelection> = []

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
                    selection: $selection,
                    selectedItems: $selectedItems
                )
                .frame(maxWidth: .infinity)

                if selection != nil {
                    Divider()
                    inspectorPanel
                        .frame(width: 260)
                }
            }
        }
        .onChange(of: appState.tunnelConfig) { _, _ in
            appState.scheduleTunnelConfigSave()
        }
    }

    // MARK: - Inspector Panel

    @ViewBuilder private var inspectorPanel: some View {
        switch selection {
        case let .rule(id):
            RuleInspectorPanel(ruleId: id)
        case let .group(id):
            GroupInspectorPanel(groupId: id)
        case nil:
            EmptyView()
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
