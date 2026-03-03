//
//  NotificationService.swift
//  tnl_ctrl
//
//  Handles macOS notifications for tunnel status changes.
//

import Foundation
import OSLog
import UserNotifications

private let logger = Logger(subsystem: "nniel.tnlctrl", category: "NotificationService")

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var previousStatus: TunnelStatus?
    private var isAuthorized = false

    private init() {
        Task {
            await requestAuthorization()
        }
    }

    // MARK: - Authorization

    private func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()

        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification authorization failed: \(error)")
        }
    }

    // MARK: - Status Notifications

    func notifyStatusChange(_ newStatus: TunnelStatus) {
        guard isAuthorized else { return }

        // Only notify on significant changes
        guard shouldNotify(from: previousStatus, to: newStatus) else {
            previousStatus = newStatus
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "tnl_ctrl"

        switch newStatus {
        case .running:
            content.body = "Connected to proxy"
            content.sound = .default
        case .stopped:
            if previousStatus == .running || previousStatus == .disconnecting {
                content.body = "Disconnected from proxy"
            } else {
                previousStatus = newStatus
                return
            }
        case .error:
            content.body = "Connection error occurred"
            content.sound = .defaultCritical
        case .connecting, .disconnecting:
            previousStatus = newStatus
            return
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
        previousStatus = newStatus
    }

    private func shouldNotify(from oldStatus: TunnelStatus?, to newStatus: TunnelStatus) -> Bool {
        guard let old = oldStatus else { return newStatus == .running }

        switch (old, newStatus) {
        case (.connecting, .running): return true
        case (.running, .stopped): return true
        case (.disconnecting, .stopped): return true
        case (_, .error): return true
        default: return false
        }
    }

    // MARK: - Error Notifications

    func notifyError(_ message: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "tnl_ctrl Error"
        content.body = message
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
