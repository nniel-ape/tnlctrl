//
//  ServicePickerView.swift
//  tnl_ctrl
//

import SwiftUI

/// Service picker with latency display and fallback selection logic
struct ServicePickerView: View {
    let services: [Service]
    @Binding var tunnelConfig: TunnelConfig

    var body: some View {
        if services.isEmpty {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("No services available")
                    .foregroundStyle(.secondary)
            }
            Text("Add a service in the Services tab first.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker("Service", selection: serviceBinding()) {
                ForEach(services) { service in
                    Label {
                        HStack {
                            Text(service.name)
                            if let latency = service.latency {
                                Text("\(latency) ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: service.protocol.systemImage)
                    }
                    .tag(service.id)
                }
            }
        }
    }

    /// Creates a binding with fallback logic for missing services
    private func serviceBinding() -> Binding<UUID> {
        Binding(
            get: {
                // If no service selected, use first available
                if let selected = tunnelConfig.selectedServiceId,
                   services.contains(where: { $0.id == selected }) {
                    return selected
                }
                return services.first?.id ?? UUID()
            },
            set: { newValue in
                tunnelConfig.selectedServiceId = newValue
            }
        )
    }
}
