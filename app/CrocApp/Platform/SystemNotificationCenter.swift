import Foundation
import UserNotifications
import os

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// `UserNotifications` behind `NotificationPosting`, and the delegate that
/// brings the app to the transfer when a notification is tapped.
@MainActor
final class SystemNotificationCenter: NSObject, NotificationPosting,
    @preconcurrency UNUserNotificationCenterDelegate
{
    nonisolated private static let log = Logger(
        subsystem: "com.bakirgdev.CrocApp", category: "notifications")
    private static let identifier = "transfer"
    private static let category = "transfer"

    private var center: UNUserNotificationCenter { .current() }

    /// Sets the delegate, so call it once at launch: a tap that relaunches the
    /// app is delivered only to a delegate set by then.
    func install() {
        center.delegate = self
        // Shown instead of the body when the user hides previews on the lock screen.
        let category = UNNotificationCategory(
            identifier: Self.category, actions: [], intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: String(
                localized: "Transfer update",
                comment: "Notification text when the user hides previews on the lock screen."),
            options: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert])
        } catch {
            Self.log.error("Notification permission request failed: \(error)")
        }
    }

    func post(_ notice: TransferNotice) {
        let content = UNMutableNotificationContent()
        content.title = notice.title
        if let body = notice.body { content.body = body }
        content.categoryIdentifier = Self.category
        content.userInfo = ["direction": notice.direction == .send ? "send" : "receive"]
        // One slot: a newer notice replaces the one on screen.
        let request = UNNotificationRequest(
            identifier: Self.identifier, content: content, trigger: nil)
        center.add(request) { error in
            if let error { Self.log.error("Posting a notification failed: \(error)") }
        }
    }

    func removeDelivered() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let direction = response.notification.request.content.userInfo["direction"] as? String
        AppRouter.shared.path = [direction == "send" ? .send : .receive]
        #if os(macOS)
        AppRouter.shared.showMainWindow()
        #endif
        completionHandler()
    }

    static var isAppActive: Bool {
        #if os(macOS)
        NSApp.isActive
        #else
        UIApplication.shared.applicationState == .active
        #endif
    }
}
