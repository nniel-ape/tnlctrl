//
//  GeneralTab.swift
//  TunnelMaster
//

import SwiftUI

struct GeneralTab: View {
    @State private var helperInstalled = false
    @State private var isCheckingHelper = false

    var body: some View {
        Form {
            Section("Privileged Helper") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("TunnelMaster Helper")
                            .font(.headline)
                        Text("Required for system-wide tunneling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isCheckingHelper {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: helperInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(helperInstalled ? .green : .red)
                    }
                }

                if !helperInstalled {
                    Button("Install Helper...") {
                        // TODO: Task 15 - SMAppService installation
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Uninstall Helper") {
                        // TODO: Task 15
                    }
                }
            }

            Section("Geo Databases") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("GeoIP / GeoSite")
                            .font(.headline)
                        Text("Last updated: Never")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Check for Updates") {
                        // TODO: Task 26 - Geo database updates
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0 (1)")
                LabeledContent("sing-box", value: "Bundled v1.10.0")

                Link("View on GitHub", destination: URL(string: "https://github.com")!)
            }
        }
        .formStyle(.grouped)
    }
}
