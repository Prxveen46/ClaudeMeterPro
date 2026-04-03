import Foundation
import UserNotifications

/// Manages usage threshold notifications via macOS notification center.
class NotificationManager {
    static let shared = NotificationManager()

    private var notifiedThresholds: Set<Int> = []
    private var lastSessionResetDate: Date?

    // User preferences
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }

    var thresholds: [Int] {
        get {
            let saved = UserDefaults.standard.array(forKey: "notificationThresholds") as? [Int]
            return saved ?? [75, 90, 100]
        }
        set { UserDefaults.standard.set(newValue, forKey: "notificationThresholds") }
    }

    init() {
        // Set defaults on first launch
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
        }
    }

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("[Notifications] Permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Check & Notify

    func checkAndNotify(previous: UsageInfo?, current: UsageInfo, countdown: String) {
        guard isEnabled else { return }

        let currentPercent = current.usagePercentInt

        // Detect session reset — clear notified thresholds
        if let newReset = current.sessionResetDate,
           let oldReset = lastSessionResetDate,
           newReset != oldReset {
            notifiedThresholds.removeAll()
        }

        // Also clear if percent dropped significantly (reset occurred)
        if let prev = previous, currentPercent < prev.usagePercentInt - 20 {
            notifiedThresholds.removeAll()
        }

        lastSessionResetDate = current.sessionResetDate

        let previousPercent = previous?.usagePercentInt ?? 0

        for threshold in thresholds.sorted() {
            if currentPercent >= threshold && previousPercent < threshold && !notifiedThresholds.contains(threshold) {
                sendNotification(percent: currentPercent, threshold: threshold, countdown: countdown)
                notifiedThresholds.insert(threshold)
            }
        }
    }

    // MARK: - Send

    private func sendNotification(percent: Int, threshold: Int, countdown: String) {
        let content = UNMutableNotificationContent()
        content.title = "Claude Usage Alert"

        if threshold >= 100 {
            content.body = "Usage has reached \(percent)% — resets in \(countdown)"
        } else {
            content.body = "Usage at \(percent)% — resets in \(countdown)"
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage-\(threshold)-\(UUID().uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}
