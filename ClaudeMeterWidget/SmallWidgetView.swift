import SwiftUI
import WidgetKit

/// Small widget: circular usage ring with percentage and countdown timer.
struct SmallWidgetView: View {
    let entry: ClaudeMeterEntry

    private var ringColor: Color { WidgetTheme.usageColor(percent: entry.sessionPercent) }

    var body: some View {
        if !entry.isConfigured {
            unconfiguredView
        } else {
            usageView
        }
    }

    private var usageView: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(min(entry.sessionPercent, 100)) / 100)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center percentage
                VStack(spacing: 0) {
                    Text("\(entry.sessionPercent)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(ringColor)
                    Text("%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            // Countdown
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(entry.countdownText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            if entry.isStale {
                Text("stale")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
            }
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor)
        }
    }

    private var unconfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.0percent")
                .font(.system(size: 32))
                .foregroundColor(WidgetTheme.amber)

            Text("Open App\nto Configure")
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor)
        }
    }
}
