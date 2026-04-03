import SwiftUI

/// Settings tab showing usage history charts, activity heatmap, and CSV export.
struct HistoryView: View {
    let historyStore: UsageHistoryStore

    @State private var selectedRange: TimeRange = .day
    @State private var snapshots: [UsageSnapshot] = []
    @State private var dailyAverages: [DailyAverage] = []
    @State private var recordCount = 0
    @State private var isLoading = false

    enum TimeRange: String, CaseIterable {
        case fiveHours = "5h"
        case day = "24h"
        case week = "7d"
        case month = "30d"
        case quarter = "90d"
    }

    var body: some View {
        VStack(spacing: 14) {
            // Time range picker
            settingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ClaudeTheme.amber)
                        Text("Usage Over Time")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Picker("", selection: $selectedRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView().controlSize(.small)
                            Spacer()
                        }
                        .frame(height: 160)
                    } else {
                        UsageLineChart(snapshots: snapshots)
                    }
                }
            }

            // Activity heatmap
            settingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ClaudeTheme.amber)
                        Text("Activity")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    ActivityHeatmap(
                        dailyAverages: dailyAverages,
                        weeksToShow: heatmapWeeks
                    )
                }
            }

            // Stats & export
            settingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "cylinder.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ClaudeTheme.amber)
                            Text("Data Points")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("\(recordCount) snapshots recorded")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        CSVExporter.exportToFile(snapshots: snapshots)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                            Text("Export CSV")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClaudeTheme.amber)
                    .controlSize(.small)
                    .disabled(snapshots.isEmpty)
                }
            }
        }
        .padding(18)
        .onAppear { loadData() }
        .onChange(of: selectedRange) { _ in loadData() }
    }

    // MARK: - Data Loading

    private func loadData() {
        isLoading = true
        Task {
            async let snapshotData = fetchSnapshots()
            async let heatmapData = historyStore.dailyAverages(daysBack: heatmapWeeks * 7)
            async let count = historyStore.recordCount()

            snapshots = await snapshotData
            dailyAverages = await heatmapData
            recordCount = await count
            isLoading = false
        }
    }

    private func fetchSnapshots() async -> [UsageSnapshot] {
        switch selectedRange {
        case .fiveHours: return await historyStore.snapshots(hoursBack: 5)
        case .day: return await historyStore.snapshots(hoursBack: 24)
        case .week: return await historyStore.snapshots(daysBack: 7)
        case .month: return await historyStore.snapshots(daysBack: 30)
        case .quarter: return await historyStore.snapshots(daysBack: 90)
        }
    }

    private var heatmapWeeks: Int {
        switch selectedRange {
        case .fiveHours, .day: return 4
        case .week: return 4
        case .month: return 8
        case .quarter: return 13
        }
    }

    // MARK: - Card

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
    }
}
