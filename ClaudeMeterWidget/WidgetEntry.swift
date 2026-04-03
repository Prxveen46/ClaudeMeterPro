import WidgetKit
import Foundation

struct ClaudeMeterEntry: TimelineEntry {
    let date: Date
    let sessionPercent: Int
    let dailyPercent: Int?
    let weeklyPercent: Int?
    let sessionResetDate: Date?
    let isConfigured: Bool
    let isStale: Bool

    var countdownText: String {
        guard let reset = sessionResetDate else { return "--" }
        let remaining = max(0, reset.timeIntervalSinceNow)
        if remaining <= 0 { return "--" }

        let total = Int(remaining)
        let h = total / 3600
        let m = (total % 3600) / 60

        if h > 0 { return "\(h)h \(m)m" }
        let s = total % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    static let placeholder = ClaudeMeterEntry(
        date: Date(),
        sessionPercent: 42,
        dailyPercent: 35,
        weeklyPercent: 28,
        sessionResetDate: Date().addingTimeInterval(7200),
        isConfigured: true,
        isStale: false
    )

    static let unconfigured = ClaudeMeterEntry(
        date: Date(),
        sessionPercent: 0,
        dailyPercent: nil,
        weeklyPercent: nil,
        sessionResetDate: nil,
        isConfigured: false,
        isStale: false
    )
}
