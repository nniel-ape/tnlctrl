//
//  OnboardingView.swift
//  tnl_ctrl
//
//  First-launch onboarding flow.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    @State private var showingAddServerSheet = false

    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                switch currentPage {
                case 0: welcomePage
                case 1: helperPage
                case 2: addServerPage
                case 3: completePage
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0 ..< totalPages, id: \.self) { page in
                    Circle()
                        .fill(page == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 16)

            Divider()

            // Navigation
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .sheet(isPresented: $showingAddServerSheet) {
            AddServerSheet()
                .environment(appState)
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Welcome to tnl_ctrl")
                .font(.title)
                .fontWeight(.semibold)

            Text("A powerful menu bar app for managing your VPN and proxy connections.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Text("tnl_ctrl lives in your menu bar for quick access.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var helperPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Install Helper")
                .font(.title)
                .fontWeight(.semibold)

            Text("tnl_ctrl requires a privileged helper to manage system-wide tunneling.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            if appState.helperInstaller.status == .installed {
                Label("Helper Installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Install Helper") {
                    Task {
                        try? await appState.helperInstaller.install()
                    }
                }
                .buttonStyle(.borderedProminent)

                Text("You may be prompted to enter your password.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var addServerPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Add Your First Server")
                .font(.title)
                .fontWeight(.semibold)

            Text("Add a server to deploy proxy services.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Button("Add Server...") {
                showingAddServerSheet = true
            }
            .buttonStyle(.borderedProminent)

            if !appState.servers.isEmpty {
                Label("\(appState.servers.count) server(s)", systemImage: "server.rack")
                    .foregroundStyle(.green)
                    .padding(.top, 8)
            }

            Spacer()
        }
    }

    private var completePage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.semibold)

            Text("Click the tnl_ctrl icon in your menu bar to connect.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            HStack(spacing: 4) {
                Image(systemName: "menubar.rectangle")
                Image(systemName: "arrow.right")
                Image(systemName: "network")
            }
            .font(.title2)
            .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "OnboardingComplete")
        dismiss()
    }

    static func shouldShowOnboarding() -> Bool {
        !UserDefaults.standard.bool(forKey: "OnboardingComplete")
    }
}
