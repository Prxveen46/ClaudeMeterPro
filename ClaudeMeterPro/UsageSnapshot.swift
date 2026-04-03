import Foundation

/// A single point-in-time record of usage data, stored in SQLite.
struct UsageSnapshot {
    let id: Int64
    let timestamp: Date
    let sessionPercent: Double
    let dailyPercent: Double?
    let weeklyPercent: Double?
    let sessionReset: Date?
    let dailyReset: Date?
    let weeklyReset: Date?

    var sessionPercentInt: Int { min(100, Int(sessionPercent * 100)) }
    var dailyPercentInt: Int? {
        guard let p = dailyPercent else { return nil }
        return min(100, Int(p * 100))
    }
    var weeklyPercentInt: Int? {
        guard let p = weeklyPercent else { return nil }
        return min(100, Int(p * 100))
    }
}

/// Aggregated daily average for heatmap display.
struct DailyAverage {
    let date: Date       // midnight of the day
    let dateString: String  // "2026-04-03"
    let avgSessionPercent: Double
}
