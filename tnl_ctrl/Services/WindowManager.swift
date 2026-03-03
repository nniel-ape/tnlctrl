//
//  WindowManager.swift
//  tnl_ctrl
//

import AppKit
import OSLog

/// Manages Settings window activation and tracking.
///
/// Provides centralized, reliable window activation with multiple fallback strategies
/// and guaranteed frontmost positioning.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private let logger = Logger(subsystem: "nniel.tnlctrl", category: "WindowManager")

    /// Weak reference to the Settings window for reliable tracking
    private weak var settingsWindow: NSWindow?

    private init() {}

    // MARK: - Window Registration

    /// Register the Settings window for tracking.
    /// Call this from SettingsWindow.onAppear via WindowAccessor.
    func registerSettingsWindow(_ window: NSWindow) {
        settingsWindow = window
        logger.debug("Registered Settings window: \(window.title)")
    }

    /// Unregister the Settings window when it closes.
    /// Call this from SettingsWindow.onDisappear.
    func unregisterSettingsWindow() {
        settingsWindow = nil
        logger.debug("Unregistered Settings window")
    }

    // MARK: - Window Activation

    /// Activate and bring Settings window to front with guaranteed frontmost positioning.
    ///
    /// Uses multiple fallback strategies and temporarily elevates window level to ensure
    /// the Settings window appears above all other windows, even when the app is in
    /// accessory mode or other apps are focused.
    func activateSettings() {
        // Delay to allow menu bar panel to dismiss first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }

            // Set activation policy to regular to allow window focus
            NSApplication.shared.setActivationPolicy(.regular)

            // Activate the app
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])

            // Find the Settings window using multiple strategies
            guard let window = findSettingsWindow() else {
                logger.warning("Could not find Settings window, will retry")
                retryBringToFront(attemptsRemaining: 5)
                return
            }

            // Bring window to front with temporary level elevation
            bringToFront(window)
        }
    }

    // MARK: - Private Helpers

    /// Find the Settings window using multiple fallback strategies.
    private func findSettingsWindow() -> NSWindow? {
        // Strategy 1: Use tracked weak reference (most reliable)
        if let window = settingsWindow, window.isVisible {
            logger.debug("Found Settings window via tracked reference")
            return window
        }

        // Strategy 2: Search by title
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
            logger.debug("Found Settings window via title search")
            return window
        }

        // Strategy 3: Search by identifier
        if let window = NSApplication.shared.windows.first(where: {
            $0.identifier?.rawValue.contains("settings") == true
        }) {
            logger.debug("Found Settings window via identifier search")
            return window
        }

        // Strategy 4: Heuristic - find any visible, key-able window (fallback)
        if let window = NSApplication.shared.windows.first(where: {
            $0.isVisible && $0.canBecomeKey && !$0.title.isEmpty
        }) {
            logger.debug("Found window via heuristic: \(window.title)")
            return window
        }

        return nil
    }

    /// Retry finding and bringing the Settings window to front.
    ///
    /// On first open, SwiftUI may not have created the window yet by the time
    /// `activateSettings()` runs. This retries with short delays to handle the race.
    private func retryBringToFront(attemptsRemaining: Int) {
        guard attemptsRemaining > 0 else {
            logger.warning("Failed to find Settings window after all retry attempts")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            if let window = findSettingsWindow() {
                bringToFront(window)
            } else {
                retryBringToFront(attemptsRemaining: attemptsRemaining - 1)
            }
        }
    }

    /// Bring window to front with guaranteed frontmost positioning.
    ///
    /// Temporarily elevates window level to .floating to ensure it appears
    /// above all other windows, then restores the original level.
    private func bringToFront(_ window: NSWindow) {
        let originalLevel = window.level

        // Temporarily elevate to floating level to guarantee frontmost
        window.level = .floating
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)

        logger.debug("Brought window '\(window.title)' to front")

        // Restore original level after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.level = originalLevel
        }
    }
}
