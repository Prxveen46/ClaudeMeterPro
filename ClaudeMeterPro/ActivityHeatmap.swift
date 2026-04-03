import SwiftUI

/// GitHub-style activity heatmap showing daily usage averages.
struct ActivityHeatmap: View {
    let dailyAverages: [DailyAverage]
    let weeksToShow: Int

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let dayLabels = ["Mon", "", "Wed", "", "Fri", "", "Sun"]

    var body: some View {
        if dailyAverages.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    ForEach([0, 25, 50, 75, 100], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level == 0 ? Color.gray.opacity(0.15) : ClaudeTheme.usageColor(percent: level))
                            .frame(width: 10, height: 10)
                    }
                    Text("More")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        // Day labels
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { i in
                                Text(dayLabels[i])
                                    .font(.system(size: 8))
                                    .foregroundStyle(.quaternary)
                                    .frame(width: 24, height: cellSize)
                            }
                        }

                        // Grid cells
                        HStack(spacing: cellSpacing) {
                            ForEach(gridColumns, id: \.0) { (weekIndex, days) in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<7, id: \.self) { dayIndex in
                                        if let avg = days[dayIndex] {
                                            cellView(percent: Int(avg.avgSessionPercent * 100))
                                                .help("\(avg.dateString): \(Int(avg.avgSessionPercent * 100))%")
                                        } else {
                                            cellView(percent: -1) // empty cell
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            Text("Activity data will appear after a few days")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func cellView(percent: Int) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(percent < 0 ? Color.gray.opacity(0.06) : (percent == 0 ? Color.gray.opacity(0.15) : ClaudeTheme.usageColor(percent: percent)))
            .frame(width: cellSize, height: cellSize)
    }

    /// Organize daily averages into a grid: array of (weekIndex, [7 optional DailyAverage]).
    private var gridColumns: [(Int, [Int: DailyAverage])] {
        let cal = Calendar.current
        var columns: [(Int, [Int: DailyAverage])] = []

        // Build a date range for the last N weeks
        let today = cal.startOfDay(for: Date())
        // Map daily averages by date string for O(1) lookup
        var avgByDate: [String: DailyAverage] = [:]
        for avg in dailyAverages {
            avgByDate[avg.dateString] = avg
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let totalDays = weeksToShow * 7
        let startDate = cal.date(byAdding: .day, value: -(totalDays - 1), to: today)!

        var weekDays: [Int: DailyAverage] = [:]
        var weekIndex = 0

        for dayOffset in 0..<totalDays {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let dayOfWeek = (cal.component(.weekday, from: date) + 5) % 7 // Mon=0

            if dayOfWeek == 0 && dayOffset > 0 {
                columns.append((weekIndex, weekDays))
                weekDays = [:]
                weekIndex += 1
            }

            let dateStr = fmt.string(from: date)
            if let avg = avgByDate[dateStr] {
                weekDays[dayOfWeek] = avg
            }
        }

        // Add final partial week
        if !weekDays.isEmpty {
            columns.append((weekIndex, weekDays))
        }

        return columns
    }
}
