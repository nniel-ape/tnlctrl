//
//  WizardView.swift
//  TunnelMaster
//
//  Multi-step wizard for deploying new proxy servers.
//

import SwiftUI

struct WizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var wizardState: WizardState

    init(server: Server, usedPorts: Set<Int> = [], usedContainerNames: Set<String> = []) {
        _wizardState = State(initialValue: WizardState(
            server: server,
            usedPorts: usedPorts,
            usedContainerNames: usedContainerNames
        ))
    }

    private var headerTitle: String {
        // During configuration/deploy, show the service name being created
        if wizardState.currentStep >= 2 {
            return "Adding \(wizardState.effectiveServiceName) to \(wizardState.server.name)"
        }
        return "Add Service to \(wizardState.server.name)"
    }

    /// Step index for display (0-based relative to visible steps)
    private var displayStepIndex: Int {
        wizardState.currentStep - wizardState.minStep
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            contentView

            Divider()

            // Footer
            footerView
        }
        .frame(width: 550, height: 450)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(headerTitle)
                .font(.title2)
                .fontWeight(.semibold)

            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0 ..< wizardState.totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= displayStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Text(wizardState.stepTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder private var contentView: some View {
        switch wizardState.currentStep {
        case 1:
            ProtocolStepView(state: wizardState)
        case 2:
            ConfigureStepView(state: wizardState)
        case 3:
            DeployStepView(state: wizardState, appState: appState, onDismiss: { dismiss() })
        default:
            EmptyView()
        }
    }

    /// Whether Back button should be shown
    private var canGoBack: Bool {
        // Must be past minStep
        guard wizardState.currentStep > wizardState.minStep else { return false }

        // On deploy step: only allow back if not deploying and not yet succeeded
        if wizardState.currentStep == 3 {
            return !wizardState.isDeploying && wizardState.deployedService == nil
        }

        return true
    }

    private var footerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            if canGoBack {
                Button("Back") {
                    wizardState.previousStep()
                }
            }

            Spacer()

            if wizardState.currentStep < 3 {
                Button("Next") {
                    wizardState.nextStep()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!wizardState.canProceed)
            } else if wizardState.deployedService != nil {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

// MARK: - Protocol Step

struct ProtocolStepView: View {
    @Bindable var state: WizardState

    var body: some View {
        Form {
            Section("Select Protocol") {
                Picker("Protocol", selection: $state.selectedProtocol) {
                    ForEach(ProtocolTemplates.deployableProtocols, id: \.self) { proto in
                        HStack {
                            Image(systemName: proto.systemImage)
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text(proto.displayName)
                                if let template = ProtocolTemplates.template(for: proto) {
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tag(proto)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
