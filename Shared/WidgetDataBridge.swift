import Foundation

/// Shared data bridge between the main app and WidgetKit extension.
/// Both targets include this file. Data flows through App Group UserDefaults.
///
/// Main app writes on each usage fetch → Widget reads via timeline refresh.
public enum WidgetDataBridge {
    /// App Group identifier — must match entitlements in both targets.
    /// Update this after provisioning your App Group in the Apple Developer portal.
    public static let appGroupID = "group.com.claudemeterpro.shared"

    private static let suiteKey = "widgetUsageData"

    /// Data payload shared between app and widget.
    public struct UsageData: Codable {
        public let sessionPercent: Int          // 0-100
        public let dailyPercent: Int?           // 0-100
        public let weeklyPercent: Int?          // 0-100
        public let sessionResetDate: Date?
        public let dailyResetDate: Date?
        public let weeklyResetDate: Date?
        public let lastUpdated: Date
        public let hasSessionKey: Bool
    }

    // MARK: - Write (Main App)

    public static func pushUsageData(_ data: UsageData) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let encoded = try? JSONEncoder().encode(data)
        defaults.set(encoded, forKey: suiteKey)
    }

    /// Convenience: push from UsageStore state.
    public static func pushFromStore(
        sessionPercent: Int,
        dailyPercent: Int?,
        weeklyPercent: Int?,
        sessionResetDate: Date?,
        dailyResetDate: Date?,
        weeklyResetDate: Date?,
        hasSessionKey: Bool
    ) {
        pushUsageData(UsageData(
            sessionPercent: sessionPercent,
            dailyPercent: dailyPercent,
            weeklyPercent: weeklyPercent,
            sessionResetDate: sessionResetDate,
            dailyResetDate: dailyResetDate,
            weeklyResetDate: weeklyResetDate,
            lastUpdated: Date(),
            hasSessionKey: hasSessionKey
        ))
    }

    // MARK: - Read (Widget)

    public static func readUsageData() -> UsageData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: suiteKey) else { return nil }
        return try? JSONDecoder().decode(UsageData.self, from: data)
    }
}
