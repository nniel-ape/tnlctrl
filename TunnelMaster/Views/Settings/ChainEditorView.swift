//
//  ChainEditorView.swift
//  TunnelMaster
//

import SwiftUI

/// Chain editor with drag-to-reorder, add menu, and flow description
struct ChainEditorView: View {
    let services: [Service]
    @Binding var tunnelConfig: TunnelConfig

    var body: some View {
        Group {
            if chainServices.isEmpty {
                HStack {
                    Image(systemName: "link.badge.plus")
                        .foregroundStyle(.secondary)
                    Text("No services in chain")
                        .foregroundStyle(.secondary)
                }
            } else {
                // Chain list with drag-to-reorder
                List {
                    ForEach(Array(chainServices.enumerated()), id: \.element.id) { index, service in
                        ChainServiceRow(service: service, index: index + 1)
                    }
                    .onMove { from, to in
                        tunnelConfig.chain.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { offsets in
                        tunnelConfig.chain.remove(atOffsets: offsets)
                    }
                }
                .frame(minHeight: 60, maxHeight: 150)
            }

            // Add to chain button
            if !availableForChain.isEmpty {
                Menu {
                    ForEach(availableForChain) { service in
                        Button {
                            tunnelConfig.chain.append(service.id)
                        } label: {
                            Label(service.name, systemImage: service.protocol.systemImage)
                        }
                    }
                } label: {
                    Label("Add to Chain", systemImage: "plus.circle")
                }
                .help("Add a service to the chain for multi-hop routing")
            }

            // Flow description
            if chainServices.count >= 2 {
                Text("Traffic routes: \(chainServices.map(\.name).joined(separator: " → "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Services currently in the chain
    private var chainServices: [Service] {
        tunnelConfig.chain.compactMap { chainId in
            services.first { $0.id == chainId }
        }
    }

    /// Services available to add to the chain
    private var availableForChain: [Service] {
        services.filter { service in
            !tunnelConfig.chain.contains(service.id)
        }
    }
}

private struct ChainServiceRow: View {
    let service: Service
    let index: Int

    var body: some View {
        HStack {
            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Position number
            Text("\(index).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            // Protocol icon
            Image(systemName: service.protocol.systemImage)
                .foregroundStyle(.blue)

            // Service name
            Text(service.name)
                .lineLimit(1)

            Spacer()
        }
    }
}
