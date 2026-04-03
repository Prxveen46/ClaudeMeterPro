import SwiftUI
import WidgetKit

/// Medium widget: session ring on the left, usage bars for all tiers on the right.
struct MediumWidgetView: View {
    let entry: ClaudeMeterEntry

    var body: some View {
        if !entry.isConfigured {
            unconfiguredView
        } else {
            usageView
        }
    }

    private var usageView: some View {
        HStack(spacing: 16) {
            // Left: compact ring
            ringSection

            // Right: tier bars
            VStack(alignment: .leading, spacing: 8) {
                tierBar(label: "Session", percent: entry.sessionPercent, icon: "bolt.fill")

                if let daily = entry.dailyPercent {
                    tierBar(label: "Daily", percent: daily, icon: "calendar")
                }

                if let weekly = entry.weeklyPercent {
                    tierBar(label: "Weekly", percent: weekly, icon: "calendar.badge.clock")
                }

                // Countdown row
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Resets in \(entry.countdownText)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    if entry.isStale {
                        Text("stale")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor)
        }
    }

    private var ringSection: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)

            Circle()
                .trim(from: 0, to: CGFloat(min(entry.sessionPercent, 100)) / 100)
                .stroke(
                    WidgetTheme.usageColor(percent: entry.sessionPercent),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(entry.sessionPercent)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetTheme.usageColor(percent: entry.sessionPercent))
                Text("%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 64, height: 64)
    }

    private func tierBar(label: String, percent: Int, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(WidgetTheme.usageColor(percent: percent))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(WidgetTheme.usageGradient(percent: percent))
                        .frame(width: max(6, geo.size.width * CGFloat(min(percent, 100)) / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var unconfiguredView: some View {
        HStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.0percent")
                .font(.system(size: 40))
                .foregroundColor(WidgetTheme.amber)

            VStack(alignment: .leading, spacing: 4) {
                Text("ClaudeMeter Pro")
                    .font(.system(size: 14, weight: .semibold))
                Text("Open the app to set up\nyour session key")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor)
        }
    }
}
