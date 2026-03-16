import SwiftUI

@main
struct ClaudeMeterProApp: App {
    @StateObject private var usageStore = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(usageStore: usageStore)
        } label: {
            MenuBarLabel(store: usageStore)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    private var percent: Int { store.usageInfo?.sessionPercentInt ?? 0 }
    private var timer: String { store.formatCountdown(store.resetSecondsRemaining) }
    private var hasData: Bool { store.usageInfo != nil }

    var body: some View {
        if !store.hasSessionKey {
            Text("⚠ Setup")
        } else if !hasData {
            Text(store.menuBarLabel).monospacedDigit()
        } else {
            switch store.menuBarStyle {
            case "battery":
                batteryStyle
            case "circular":
                circularStyle
            case "segments":
                segmentsStyle
            case "dualbar":
                dualBarStyle
            case "gauge":
                gaugeStyle
            default:
                minimalStyle
            }
        }
    }

    // MARK: - Minimal
    private var minimalStyle: some View {
        Text("\(percent)% | \(timer)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .monospacedDigit()
    }

    // MARK: - Battery
    private var batteryStyle: some View {
        HStack(spacing: 5) {
            // Battery icon
            HStack(spacing: 0.5) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .stroke(Color.white, lineWidth: 0.8)
                        .frame(width: 18, height: 9)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: max(1, CGFloat(percent) / 100 * 16), height: 7)
                        .padding(.leading, 1)
                }
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.white)
                    .frame(width: 1.5, height: 4)
            }
            Text("\(percent)%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }

    // MARK: - Circular
    private var circularStyle: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 14, height: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-90))
            }
            Text("\(percent)%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }

    // MARK: - Segments
    private var segmentsStyle: some View {
        HStack(spacing: 5) {
            HStack(spacing: 1.5) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(i < filledSegments ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 3, height: CGFloat(5 + i * 2))
                }
            }
            Text("\(percent)%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }

    private var filledSegments: Int {
        if percent >= 80 { return 5 }
        if percent >= 60 { return 4 }
        if percent >= 40 { return 3 }
        if percent >= 20 { return 2 }
        if percent > 0 { return 1 }
        return 0
    }

    // MARK: - Dual Bar
    private var dualBarStyle: some View {
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 22, height: 6)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: max(1, CGFloat(percent) / 100 * 22), height: 6)
            }
            Text("\(percent)%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }

    // MARK: - Gauge
    private var gaugeStyle: some View {
        HStack(spacing: 4) {
            Image(systemName: gaugeIcon)
                .font(.system(size: 12))
            Text("\(percent)%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }

    private var gaugeIcon: String {
        if percent >= 80 { return "gauge.with.dots.needle.100percent" }
        if percent >= 50 { return "gauge.with.dots.needle.67percent" }
        if percent >= 20 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }
}
