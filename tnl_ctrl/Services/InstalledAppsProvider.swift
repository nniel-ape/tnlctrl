//
//  InstalledAppsProvider.swift
//  tnl_ctrl
//
//  Scans and provides installed applications for the rule builder.
//

import AppKit
import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "nniel.tnlctrl", category: "InstalledAppsProvider")

/// Represents an installed application
struct InstalledApp: Identifiable, Hashable {
    let id: String // Bundle ID or process name
    let name: String
    let path: String
    let processName: String

    /// Icon is loaded separately to avoid Sendable issues
    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: path)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

/// Provides installed applications data
@MainActor
final class InstalledAppsProvider: ObservableObject {
    static let shared = InstalledAppsProvider()

    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isLoading = false
    @Published private(set) var recentApps: [InstalledApp] = []

    private var hasLoaded = false

    private init() {}

    // MARK: - Public API

    /// Load apps if not already loaded
    func loadIfNeeded() {
        guard !hasLoaded, !isLoading else { return }
        Task {
            await load()
        }
    }

    /// Force reload apps
    func reload() {
        Task {
            await load()
        }
    }

    /// Search apps by name
    func search(_ query: String) -> [InstalledApp] {
        guard !query.isEmpty else { return apps }
        let lowercased = query.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(lowercased) ||
                $0.processName.lowercased().contains(lowercased)
        }
    }

    /// Update recently used apps from running processes
    func updateRecentApps() {
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { runningApp -> InstalledApp? in
                guard let bundleURL = runningApp.bundleURL,
                      let name = runningApp.localizedName
                else {
                    return nil
                }
                let processName = bundleURL.deletingPathExtension().lastPathComponent
                return InstalledApp(
                    id: runningApp.bundleIdentifier ?? processName,
                    name: name,
                    path: bundleURL.path,
                    processName: processName
                )
            }

        recentApps = Array(runningApps.prefix(10))
    }

    // MARK: - Private

    private func load() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        let appPaths = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        var foundApps: [InstalledApp] = []

        for basePath in appPaths {
            let apps = await scanDirectory(basePath)
            foundApps.append(contentsOf: apps)
        }

        // Sort by name
        foundApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Remove duplicates (keep first occurrence)
        var seen = Set<String>()
        foundApps = foundApps.filter { app in
            if seen.contains(app.id) {
                return false
            }
            seen.insert(app.id)
            return true
        }

        apps = foundApps
        updateRecentApps()

        // swiftformat:disable:next redundantSelf
        logger.info("Loaded \(self.apps.count) installed apps")
    }

    private func scanDirectory(_ path: String) async -> [InstalledApp] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        else {
            return []
        }

        var apps: [InstalledApp] = []

        for url in contents {
            // Only process .app bundles
            guard url.pathExtension == "app" else { continue }

            if let app = createApp(from: url) {
                apps.append(app)
            }
        }

        return apps
    }

    private func createApp(from url: URL) -> InstalledApp? {
        let bundle = Bundle(url: url)

        // Try to get the display name
        var name = url.deletingPathExtension().lastPathComponent

        if let bundle {
            // Use bundle display name if available
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                name = displayName
            } else if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                name = bundleName
            }
        }

        // Get bundle ID for identification
        let bundleId = bundle?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent

        // Get the executable name (process name)
        var processName = url.deletingPathExtension().lastPathComponent
        if let bundle,
           let executableName = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String {
            processName = executableName
        }

        return InstalledApp(
            id: bundleId,
            name: name,
            path: url.path,
            processName: processName
        )
    }
}

// MARK: - Common Apps Database

extension InstalledAppsProvider {
    /// Well-known apps that might not be in standard locations
    static let commonApps: [(name: String, processName: String)] = [
        ("Safari", "Safari"),
        ("Google Chrome", "Google Chrome"),
        ("Firefox", "firefox"),
        ("Arc", "Arc"),
        ("Microsoft Edge", "Microsoft Edge"),
        ("Brave Browser", "Brave Browser"),
        ("Slack", "Slack"),
        ("Discord", "Discord"),
        ("Telegram", "Telegram"),
        ("WhatsApp", "WhatsApp"),
        ("Zoom", "zoom.us"),
        ("Spotify", "Spotify"),
        ("Visual Studio Code", "Code"),
        ("iTerm", "iTerm2"),
        ("Terminal", "Terminal"),
        ("Finder", "Finder"),
        ("Mail", "Mail"),
        ("Notes", "Notes"),
        ("Calendar", "Calendar"),
        ("Xcode", "Xcode"),
        ("Steam", "steam_osx"),
        ("Battle.net", "Battle.net"),
        ("VLC", "VLC"),
        ("Dropbox", "Dropbox"),
        ("OneDrive", "OneDrive"),
        ("Docker", "Docker"),
        ("Postman", "Postman"),
        ("Figma", "Figma"),
        ("Notion", "Notion"),
        ("1Password", "1Password"),
        ("Alfred", "Alfred"),
        ("Raycast", "Raycast")
    ]
}
