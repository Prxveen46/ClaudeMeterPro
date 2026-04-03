import SwiftUI

/// A line chart that draws usage percentage over time with color-coded segments.
struct UsageLineChart: View {
    let snapshots: [UsageSnapshot]
    let maxPercent: Double = 1.0

    var body: some View {
        if snapshots.isEmpty {
            emptyState
        } else {
            chartContent
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No data yet")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text("Usage will appear here after a few polls")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private var chartContent: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let inset: CGFloat = 30 // left axis labels

                ZStack(alignment: .topLeading) {
                    // Grid lines
                    gridLines(width: w - inset, height: h, inset: inset)

                    // Line chart
                    chartPath(width: w - inset, height: h, inset: inset)

                    // Y axis labels
                    yAxisLabels(height: h)
                }
            }
            .frame(minHeight: 160)

            // X axis time labels
            xAxisLabels
        }
    }

    // MARK: - Grid

    private func gridLines(width: CGFloat, height: CGFloat, inset: CGFloat) -> some View {
        ZStack {
            ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                let y = height - (height * CGFloat(level))
                Path { path in
                    path.move(to: CGPoint(x: inset, y: y))
                    path.addLine(to: CGPoint(x: inset + width, y: y))
                }
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Chart Path

    private func chartPath(width: CGFloat, height: CGFloat, inset: CGFloat) -> some View {
        let points = computePoints(width: width, height: height, inset: inset)

        return ZStack {
            // Fill area under the line
            if points.count >= 2 {
                Path { path in
                    path.move(to: CGPoint(x: points[0].x, y: height))
                    for pt in points {
                        path.addLine(to: CGPoint(x: pt.x, y: pt.y))
                    }
                    path.addLine(to: CGPoint(x: points.last!.x, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [ClaudeTheme.amber.opacity(0.15), ClaudeTheme.amber.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Colored line segments
            ForEach(0..<max(0, points.count - 1), id: \.self) { i in
                let start = points[i]
                let end = points[i + 1]
                let avgPercent = Int((snapshots[i].sessionPercent + snapshots[min(i + 1, snapshots.count - 1)].sessionPercent) / 2 * 100)

                // Skip gaps (> 2x expected interval between points)
                if i + 1 < snapshots.count {
                    let gap = snapshots[i + 1].timestamp.timeIntervalSince(snapshots[i].timestamp)
                    if gap < 7200 { // 2 hours max gap
                        Path { path in
                            path.move(to: CGPoint(x: start.x, y: start.y))
                            path.addLine(to: CGPoint(x: end.x, y: end.y))
                        }
                        .stroke(ClaudeTheme.usageColor(percent: avgPercent), lineWidth: 2)
                    }
                }
            }
        }
    }

    private func computePoints(width: CGFloat, height: CGFloat, inset: CGFloat) -> [(x: CGFloat, y: CGFloat)] {
        guard snapshots.count >= 2 else {
            return snapshots.map { _ in (x: inset, y: height / 2) }
        }

        let minTime = snapshots.first!.timestamp.timeIntervalSince1970
        let maxTime = snapshots.last!.timestamp.timeIntervalSince1970
        let timeRange = max(1, maxTime - minTime)

        return snapshots.map { s in
            let xNorm = (s.timestamp.timeIntervalSince1970 - minTime) / timeRange
            let yNorm = min(s.sessionPercent / maxPercent, 1.0)
            return (
                x: inset + CGFloat(xNorm) * width,
                y: height - CGFloat(yNorm) * height
            )
        }
    }

    // MARK: - Axes

    private func yAxisLabels(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach([0, 25, 50, 75, 100], id: \.self) { level in
                let y = height - (height * CGFloat(level) / 100)
                Text("\(level)%")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .position(x: 14, y: y)
            }
        }
    }

    private var xAxisLabels: some View {
        HStack {
            if let first = snapshots.first, let last = snapshots.last {
                Text(formatTime(first.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
                Spacer()
                Text(formatTime(last.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.leading, 30)
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        let hours = abs(date.timeIntervalSinceNow) / 3600
        if hours < 24 {
            fmt.dateFormat = "h:mm a"
        } else {
            fmt.dateFormat = "MMM d, h a"
        }
        return fmt.string(from: date)
    }
}
