//
//  GeoDatabaseUpdater.swift
//  tnl_ctrl
//
//  Check for and download updated GeoIP/GeoSite databases.
//

import Foundation

private enum GeoURLs {
    // swiftlint:disable force_unwrapping
    static let geoip = URL(string: "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db")!
    static let geosite = URL(string: "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db")!
    // swiftlint:enable force_unwrapping
}

@Observable
@MainActor
final class GeoDatabaseUpdater {
    static let shared = GeoDatabaseUpdater()

    private let geoipURL = GeoURLs.geoip
    private let geositeURL = GeoURLs.geosite

    private(set) var isChecking = false
    private(set) var isUpdating = false
    private(set) var updateProgress: Double = 0
    private(set) var lastUpdateDate: Date?
    private(set) var updateAvailable = false
    private(set) var error: String?

    private let userDefaults = UserDefaults.standard
    private let lastUpdateKey = "GeoDatabase.LastUpdate"
    private let geoipETagKey = "GeoDatabase.GeoIP.ETag"
    private let geositeETagKey = "GeoDatabase.GeoSite.ETag"

    private init() {
        self.lastUpdateDate = userDefaults.object(forKey: lastUpdateKey) as? Date
    }

    // MARK: - Check for Updates

    func checkForUpdates() async {
        isChecking = true
        error = nil

        do {
            let geoipNeedsUpdate = try await checkURLForUpdate(geoipURL, etagKey: geoipETagKey)
            let geositeNeedsUpdate = try await checkURLForUpdate(geositeURL, etagKey: geositeETagKey)

            updateAvailable = geoipNeedsUpdate || geositeNeedsUpdate
        } catch {
            self.error = "Failed to check for updates: \(error.localizedDescription)"
        }

        isChecking = false
    }

    private func checkURLForUpdate(_ url: URL, etagKey: String) async throws -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return true
        }

        let newETag = httpResponse.value(forHTTPHeaderField: "ETag")
        let storedETag = userDefaults.string(forKey: etagKey)

        return newETag != storedETag
    }

    // MARK: - Download Updates

    func update() async {
        isUpdating = true
        updateProgress = 0
        error = nil

        do {
            // Download GeoIP
            updateProgress = 0.1
            let geoipData = try await downloadFile(geoipURL)
            updateProgress = 0.4

            // Download GeoSite
            let geositeData = try await downloadFile(geositeURL)
            updateProgress = 0.7

            // Save to app support directory
            let supportDir = try getGeoDatabaseDirectory()
            try geoipData.write(to: supportDir.appendingPathComponent("geoip.db"))
            try geositeData.write(to: supportDir.appendingPathComponent("geosite.db"))
            updateProgress = 0.9

            // Update stored ETags
            await updateStoredETags()

            // Update last update date
            lastUpdateDate = Date()
            userDefaults.set(lastUpdateDate, forKey: lastUpdateKey)

            updateProgress = 1.0
            updateAvailable = false
        } catch {
            self.error = "Update failed: \(error.localizedDescription)"
        }

        isUpdating = false
    }

    private func downloadFile(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw GeoUpdateError.downloadFailed
        }

        return data
    }

    private func updateStoredETags() async {
        // Fetch current ETags and store them
        for (url, key) in [(geoipURL, geoipETagKey), (geositeURL, geositeETagKey)] {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            if let (_, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse,
               let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                userDefaults.set(etag, forKey: key)
            }
        }
    }

    // MARK: - File Management

    func getGeoDatabaseDirectory() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw GeoUpdateError.directoryNotFound
        }
        let geoDir = appSupport.appendingPathComponent("tnl_ctrl/GeoDB")

        if !FileManager.default.fileExists(atPath: geoDir.path) {
            try FileManager.default.createDirectory(at: geoDir, withIntermediateDirectories: true)
        }

        return geoDir
    }

    func geoipPath() -> URL? {
        try? getGeoDatabaseDirectory().appendingPathComponent("geoip.db")
    }

    func geositePath() -> URL? {
        try? getGeoDatabaseDirectory().appendingPathComponent("geosite.db")
    }

    func hasLocalDatabases() -> Bool {
        guard let geoip = geoipPath(), let geosite = geositePath() else { return false }
        return FileManager.default.fileExists(atPath: geoip.path) &&
            FileManager.default.fileExists(atPath: geosite.path)
    }
}

// MARK: - Errors

enum GeoUpdateError: LocalizedError {
    case downloadFailed
    case saveFailed
    case directoryNotFound

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            "Failed to download geo database"
        case .saveFailed:
            "Failed to save geo database"
        case .directoryNotFound:
            "Application Support directory not found"
        }
    }
}
