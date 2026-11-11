import UserNotifications

enum NotificationAuthorization: Equatable {
    case notDetermined
    case authorized
    case denied
}

protocol NotificationService {
    func authorization() async -> NotificationAuthorization
    /// Shows the macOS permission prompt if the user has not decided yet.
    func requestAuthorization() async -> NotificationAuthorization
    /// Best effort: does nothing if notifications are not allowed. Posting
    /// the same identifier again replaces the earlier notification.
    func post(identifier: String, title: String, body: String)
}

/// Local notifications only.
final class UserNotificationService: NSObject, NotificationService, UNUserNotificationCenterDelegate {
    private var center: UNUserNotificationCenter { .current() }

    /// Lets banners appear even while NekoDesu's panel is open.
    func activate() {
        center.delegate = self
    }

    func authorization() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .authorized
        }
    }

    func requestAuthorization() async -> NotificationAuthorization {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        return await authorization()
    }

    func post(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil)) { _ in }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
