import WidgetKit
import Shared

struct ClaudeMeterTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClaudeMeterEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ClaudeMeterEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeMeterEntry>) -> Void) {
        let entry = currentEntry()

        // Refresh every 5 minutes to keep countdown and percentages current.
        // The main app also triggers reloadAllTimelines() on each fetch.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func currentEntry() -> ClaudeMeterEntry {
        guard let data = WidgetDataBridge.readUsageData(), data.hasSessionKey else {
            return .unconfigured
        }

        let staleCutoff: TimeInterval = 600 // 10 minutes
        let isStale = Date().timeIntervalSince(data.lastUpdated) > staleCutoff

        return ClaudeMeterEntry(
            date: Date(),
            sessionPercent: data.sessionPercent,
            dailyPercent: data.dailyPercent,
            weeklyPercent: data.weeklyPercent,
            sessionResetDate: data.sessionResetDate,
            isConfigured: true,
            isStale: isStale
        )
    }
}
