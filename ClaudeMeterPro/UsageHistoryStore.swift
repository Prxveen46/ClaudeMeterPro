import Foundation
import SQLite3

/// Persists usage snapshots to a local SQLite database for history, charts, and predictions.
class UsageHistoryStore: @unchecked Sendable {
    static let shared = UsageHistoryStore()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.claudemeterpro.history", qos: .utility)

    private static var dbURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ClaudeMeterPro/history.db")
    }

    init() {
        queue.sync { openDatabase() }
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let url = Self.dbURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            print("[HistoryStore] Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
            return
        }

        let createTable = """
        CREATE TABLE IF NOT EXISTS usage_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            session_percent REAL NOT NULL,
            daily_percent REAL,
            weekly_percent REAL,
            session_reset TEXT,
            daily_reset TEXT,
            weekly_reset TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_timestamp ON usage_history(timestamp);
        """
        sqlite3_exec(db, createTable, nil, nil, nil)
    }

    // MARK: - Insert

    func recordSnapshot(_ info: UsageInfo) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                defer { continuation.resume() }
                guard let self, let db = self.db else { return }

                let sql = """
                INSERT INTO usage_history (timestamp, session_percent, daily_percent, weekly_percent, session_reset, daily_reset, weekly_reset)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(stmt) }

                sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
                sqlite3_bind_double(stmt, 2, info.sessionPercent)
                self.bindOptionalDouble(stmt, 3, info.daily?.percent)
                self.bindOptionalDouble(stmt, 4, info.weekly?.percent)
                self.bindOptionalDate(stmt, 5, info.sessionResetDate)
                self.bindOptionalDate(stmt, 6, info.daily?.resetDate)
                self.bindOptionalDate(stmt, 7, info.weekly?.resetDate)

                sqlite3_step(stmt)
            }
        }
    }

    // MARK: - Query

    func snapshots(hoursBack: Int) async -> [UsageSnapshot] {
        let since = Date().addingTimeInterval(-Double(hoursBack) * 3600)
        return await querySnapshots(since: since, downsample: hoursBack > 24)
    }

    func snapshots(daysBack: Int) async -> [UsageSnapshot] {
        let since = Date().addingTimeInterval(-Double(daysBack) * 86400)
        return await querySnapshots(since: since, downsample: daysBack > 1)
    }

    private func querySnapshots(since: Date, downsample: Bool) async -> [UsageSnapshot] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let db = self.db else {
                    continuation.resume(returning: [])
                    return
                }

                let sql: String
                if downsample {
                    // Hourly averages for large ranges
                    sql = """
                    SELECT 0 as id, AVG(timestamp) as timestamp,
                           AVG(session_percent), AVG(daily_percent), AVG(weekly_percent),
                           NULL, NULL, NULL
                    FROM usage_history
                    WHERE timestamp >= ?
                    GROUP BY CAST(timestamp / 3600 AS INTEGER)
                    ORDER BY timestamp ASC
                    """
                } else {
                    sql = """
                    SELECT id, timestamp, session_percent, daily_percent, weekly_percent,
                           session_reset, daily_reset, weekly_reset
                    FROM usage_history
                    WHERE timestamp >= ?
                    ORDER BY timestamp ASC
                    """
                }

                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    continuation.resume(returning: [])
                    return
                }
                defer { sqlite3_finalize(stmt) }

                sqlite3_bind_double(stmt, 1, since.timeIntervalSince1970)

                var results: [UsageSnapshot] = []
                while sqlite3_step(stmt) == SQLITE_ROW {
                    results.append(self.readSnapshot(stmt))
                }
                continuation.resume(returning: results)
            }
        }
    }

    func dailyAverages(daysBack: Int) async -> [DailyAverage] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let db = self.db else {
                    continuation.resume(returning: [])
                    return
                }

                let since = Date().addingTimeInterval(-Double(daysBack) * 86400)
                let sql = """
                SELECT DATE(timestamp, 'unixepoch', 'localtime') as day,
                       AVG(session_percent) as avg_session
                FROM usage_history
                WHERE timestamp >= ?
                GROUP BY day
                ORDER BY day ASC
                """

                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    continuation.resume(returning: [])
                    return
                }
                defer { sqlite3_finalize(stmt) }

                sqlite3_bind_double(stmt, 1, since.timeIntervalSince1970)

                let dateFmt = DateFormatter()
                dateFmt.dateFormat = "yyyy-MM-dd"

                var results: [DailyAverage] = []
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let dayStr = String(cString: sqlite3_column_text(stmt, 0))
                    let avg = sqlite3_column_double(stmt, 1)
                    let date = dateFmt.date(from: dayStr) ?? Date()
                    results.append(DailyAverage(date: date, dateString: dayStr, avgSessionPercent: avg))
                }
                continuation.resume(returning: results)
            }
        }
    }

    /// Recent snapshots for prediction calculation.
    func recentSnapshots(minutesBack: Int = 30) async -> [UsageSnapshot] {
        let since = Date().addingTimeInterval(-Double(minutesBack) * 60)
        return await querySnapshots(since: since, downsample: false)
    }

    // MARK: - Maintenance

    func pruneOldRecords(olderThanDays: Int = 90) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                defer { continuation.resume() }
                guard let self, let db = self.db else { return }

                let cutoff = Date().addingTimeInterval(-Double(olderThanDays) * 86400)
                let sql = "DELETE FROM usage_history WHERE timestamp < ?"
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_double(stmt, 1, cutoff.timeIntervalSince1970)
                sqlite3_step(stmt)
            }
        }
    }

    func recordCount() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let db = self.db else {
                    continuation.resume(returning: 0)
                    return
                }
                let sql = "SELECT COUNT(*) FROM usage_history"
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    continuation.resume(returning: 0)
                    return
                }
                defer { sqlite3_finalize(stmt) }
                sqlite3_step(stmt)
                continuation.resume(returning: Int(sqlite3_column_int64(stmt, 0)))
            }
        }
    }

    // MARK: - Helpers

    // Shared formatter — all history work runs serialized on `queue`, so one
    // instance is safe and avoids allocating a formatter per read/write row.
    private static let iso: ISO8601DateFormatter = ISO8601DateFormatter()

    private func readSnapshot(_ stmt: OpaquePointer?) -> UsageSnapshot {
        UsageSnapshot(
            id: sqlite3_column_int64(stmt, 0),
            timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            sessionPercent: sqlite3_column_double(stmt, 2),
            dailyPercent: sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil,
            weeklyPercent: sqlite3_column_type(stmt, 4) != SQLITE_NULL ? sqlite3_column_double(stmt, 4) : nil,
            sessionReset: columnDate(stmt, 5, formatter: Self.iso),
            dailyReset: columnDate(stmt, 6, formatter: Self.iso),
            weeklyReset: columnDate(stmt, 7, formatter: Self.iso)
        )
    }

    private func columnDate(_ stmt: OpaquePointer?, _ col: Int32, formatter: ISO8601DateFormatter) -> Date? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        let text = String(cString: sqlite3_column_text(stmt, col))
        return formatter.date(from: text)
    }

    private func bindOptionalDouble(_ stmt: OpaquePointer?, _ index: Int32, _ value: Double?) {
        if let v = value {
            sqlite3_bind_double(stmt, index, v)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindOptionalDate(_ stmt: OpaquePointer?, _ index: Int32, _ date: Date?) {
        if let d = date {
            let text = Self.iso.string(from: d)
            // SQLITE_TRANSIENT — tells SQLite to copy the string. Using
            // SQLITE_STATIC (nil) with a local `let` leaves a dangling
            // pointer once the function returns, before sqlite3_step runs.
            sqlite3_bind_text(stmt, index, text, -1, Self.sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private static let sqliteTransient = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self
    )
}
