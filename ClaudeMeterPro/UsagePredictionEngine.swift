import Foundation

/// Calculates usage rate from recent history and predicts time until limit.
struct UsagePredictionEngine {

    struct Prediction {
        let estimatedSeconds: TimeInterval  // seconds until 100%
        let ratePerHour: Double             // percent/hour consumption rate

        var formatted: String {
            let total = max(0, Int(estimatedSeconds))
            let h = total / 3600
            let m = (total % 3600) / 60

            if h > 24 {
                let d = h / 24
                return "~\(d)d \(h % 24)h"
            }
            if h > 0 {
                return "~\(h)h \(m)m"
            }
            if m > 0 {
                return "~\(m)m"
            }
            return "< 1m"
        }
    }

    /// Calculate prediction from recent snapshots.
    /// Returns nil if rate is zero/negative or insufficient data.
    static func predict(snapshots: [UsageSnapshot], currentPercent: Double) -> Prediction? {
        guard snapshots.count >= 2 else { return nil }

        let first = snapshots.first!
        let last = snapshots.last!

        let timeElapsed = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeElapsed > 60 else { return nil } // need at least 1 minute of data

        let percentChange = last.sessionPercent - first.sessionPercent

        // Rate must be positive (usage increasing)
        guard percentChange > 0 else { return nil }

        let ratePerSecond = percentChange / timeElapsed
        let ratePerHour = ratePerSecond * 3600

        let remaining = 1.0 - currentPercent
        guard remaining > 0 else { return nil }

        let secondsUntilLimit = remaining / ratePerSecond

        // Ignore predictions > 7 days (unreliable)
        guard secondsUntilLimit < 7 * 86400 else { return nil }

        return Prediction(estimatedSeconds: secondsUntilLimit, ratePerHour: ratePerHour)
    }

    /// Predict for a specific tier (daily, weekly) using its own percent values.
    static func predictTier(snapshots: [UsageSnapshot], currentPercent: Double, tierKeyPath: KeyPath<UsageSnapshot, Double?>) -> Prediction? {
        let filtered = snapshots.compactMap { s -> (Date, Double)? in
            guard let p = s[keyPath: tierKeyPath] else { return nil }
            return (s.timestamp, p)
        }

        guard filtered.count >= 2 else { return nil }

        let first = filtered.first!
        let last = filtered.last!

        let timeElapsed = last.0.timeIntervalSince(first.0)
        guard timeElapsed > 60 else { return nil }

        let percentChange = last.1 - first.1
        guard percentChange > 0 else { return nil }

        let ratePerSecond = percentChange / timeElapsed
        let remaining = 1.0 - currentPercent
        guard remaining > 0 else { return nil }

        let secondsUntilLimit = remaining / ratePerSecond
        guard secondsUntilLimit < 7 * 86400 else { return nil }

        return Prediction(estimatedSeconds: secondsUntilLimit, ratePerHour: ratePerSecond * 3600)
    }
}
