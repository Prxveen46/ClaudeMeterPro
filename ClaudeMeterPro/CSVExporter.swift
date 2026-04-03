import Foundation
import AppKit

/// Exports usage history snapshots to CSV format.
struct CSVExporter {

    /// Generate CSV string from snapshots.
    static func csvString(from snapshots: [UsageSnapshot]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = ["Timestamp,Session %,Daily %,Weekly %"]

        for s in snapshots {
            let ts = iso.string(from: s.timestamp)
            let session = String(format: "%.1f", s.sessionPercent * 100)
            let daily = s.dailyPercent.map { String(format: "%.1f", $0 * 100) } ?? ""
            let weekly = s.weeklyPercent.map { String(format: "%.1f", $0 * 100) } ?? ""
            lines.append("\(ts),\(session),\(daily),\(weekly)")
        }

        return lines.joined(separator: "\n")
    }

    /// Show save dialog and write CSV to user-selected location.
    static func exportToFile(snapshots: [UsageSnapshot]) {
        let csv = csvString(from: snapshots)

        let dateStr: String = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: Date())
        }()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "ClaudeMeterPro-Usage-\(dateStr).csv"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("[CSVExporter] Failed to write: \(error.localizedDescription)")
            }
        }
    }
}
