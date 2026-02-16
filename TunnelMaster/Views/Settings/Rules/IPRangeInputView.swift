//
//  IPRangeInputView.swift
//  TunnelMaster
//
//  Visual IP range input with presets and CIDR calculator.
//

import SwiftUI

struct IPRangeInputView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var ipAddress = ""
    @State private var cidrPrefix = 24
    @State private var selectedPreset: IPRangePresets.IPPreset?

    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    presetsSection
                    Divider()
                    manualInputSection
                }
            }
            Divider()
            footer
        }
        .frame(width: 450, height: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "number")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add IP Range Rule")
                    .font(.headline)
                Text("Route traffic by IP address or CIDR range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Presets")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 8) {
                ForEach(IPRangePresets.presets) { preset in
                    presetCard(preset)
                }
            }
        }
        .padding()
    }

    private func presetCard(_ preset: IPRangePresets.IPPreset) -> some View {
        Button {
            selectedPreset = preset
            // Parse CIDR
            let parts = preset.cidr.split(separator: "/")
            if parts.count == 2 {
                ipAddress = String(parts[0])
                cidrPrefix = Int(parts[1]) ?? 24
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .foregroundStyle(.orange)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(preset.cidr)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }

                Spacer()

                if selectedPreset?.id == preset.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(8)
            .background(selectedPreset?.id == preset.id ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manual Input Section

    private var manualInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Input")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                // IP Address field
                VStack(alignment: .leading, spacing: 4) {
                    Text("IP Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("192.168.1.0", text: $ipAddress)
                        .textFieldStyle(.roundedBorder)
                        .fontDesign(.monospaced)
                        .onChange(of: ipAddress) { _, _ in
                            selectedPreset = nil
                        }
                }

                // CIDR prefix
                VStack(alignment: .leading, spacing: 4) {
                    Text("CIDR Prefix")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("/")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $cidrPrefix) {
                            ForEach([8, 12, 16, 20, 24, 28, 32], id: \.self) { prefix in
                                Text("\(prefix)").tag(prefix)
                            }
                        }
                        .frame(width: 70)
                        .onChange(of: cidrPrefix) { _, _ in
                            selectedPreset = nil
                        }
                    }
                }
            }

            // Range preview
            if !ipAddress.isEmpty, isValidIP(ipAddress) {
                rangePreview
            } else if !ipAddress.isEmpty {
                Text("Invalid IP address format")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private var rangePreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Range Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                // CIDR notation
                HStack {
                    Image(systemName: "number")
                        .foregroundStyle(.orange)
                    Text(cidrNotation)
                        .fontDesign(.monospaced)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.1))
                .clipShape(Capsule())

                // IP count
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.secondary)
                    Text(ipCountDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Range display
            if let range = calculateRange() {
                Text("\(range.start) – \(range.end)")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Add Rule") {
                onSelect(cidrNotation)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValidInput)
        }
        .padding()
    }

    // MARK: - Helpers

    private var cidrNotation: String {
        "\(ipAddress)/\(cidrPrefix)"
    }

    private var isValidInput: Bool {
        !ipAddress.isEmpty && isValidIP(ipAddress)
    }

    private var ipCountDescription: String {
        let count = 1 << (32 - cidrPrefix)
        if count >= 1_000_000 {
            return "\(count / 1_000_000)M IPs"
        } else if count >= 1000 {
            return "\(count / 1000)K IPs"
        } else {
            return "\(count) IPs"
        }
    }

    private func isValidIP(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            if let num = Int(part), num >= 0, num <= 255 {
                return true
            }
            return false
        }
    }

    private func calculateRange() -> (start: String, end: String)? {
        guard isValidIP(ipAddress) else { return nil }

        let parts = ipAddress.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return nil }

        let ipNum = (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
        let mask = (0xFFFF_FFFF << (32 - cidrPrefix)) & 0xFFFF_FFFF
        let networkNum = ipNum & Int(mask)
        let broadcastNum = networkNum | Int(~mask & 0xFFFF_FFFF)

        func numToIP(_ num: Int) -> String {
            let a = (num >> 24) & 0xFF
            let b = (num >> 16) & 0xFF
            let c = (num >> 8) & 0xFF
            let d = num & 0xFF
            return "\(a).\(b).\(c).\(d)"
        }

        return (numToIP(networkNum), numToIP(broadcastNum))
    }
}
