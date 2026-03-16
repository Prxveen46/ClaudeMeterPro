import SwiftUI

@main
struct ClaudeMeterProApp: App {
    @StateObject private var usageStore = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(usageStore: usageStore)
        } label: {
            MenuBarLabel(store: usageStore)
                // Force SwiftUI to recreate the label when style changes
                .id("menubar-\(usageStore.menuBarStyle)-\(usageStore.menuBarLabel)")
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
            Label("Setup", systemImage: "exclamationmark.triangle")
        } else if !hasData {
            Text(store.menuBarLabel).monospacedDigit()
        } else {
            switch store.menuBarStyle {
            case "battery":   batteryStyle
            case "circular":  circularStyle
            case "segments":  segmentsStyle
            case "dualbar":   dualBarStyle
            case "gauge":     gaugeStyle
            default:          minimalStyle
            }
        }
    }

    // MARK: - Minimal: "3% | 4h 39m"
    private var minimalStyle: some View {
        Text("\(percent)% | \(timer)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .monospacedDigit()
    }

    // MARK: - Battery: SF Symbol + metrics
    private var batteryStyle: some View {
        HStack(spacing: 3) {
            Image(systemName: batteryIcon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 16))
            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var batteryIcon: String {
        if percent >= 88 { return "battery.100" }
        if percent >= 63 { return "battery.75" }
        if percent >= 38 { return "battery.50" }
        if percent >= 13 { return "battery.25" }
        return "battery.0"
    }

    // MARK: - Circular: ring + metrics
    private var circularStyle: some View {
        HStack(spacing: 4) {
            ZStack {
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .opacity(percent > 0 ? 1 : 0.3)
            }
            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Segments: chart bars + metrics
    private var segmentsStyle: some View {
        HStack(spacing: 3) {
            Image(systemName: segmentsIcon)
                .font(.system(size: 14))
            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var segmentsIcon: String {
        if percent >= 80 { return "chart.bar.fill" }
        if percent >= 40 { return "chart.bar.xaxis" }
        return "chart.bar"
    }

    // MARK: - Dual Bar: line progress + metrics
    private var dualBarStyle: some View {
        HStack(spacing: 3) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 14))
            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Gauge: gauge icon + metrics
    private var gaugeStyle: some View {
        HStack(spacing: 3) {
            Image(systemName: gaugeIcon)
                .font(.system(size: 14))
            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
            Text(timer)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var gaugeIcon: String {
        if percent >= 75 { return "gauge.with.dots.needle.100percent" }
        if percent >= 50 { return "gauge.with.dots.needle.67percent" }
        if percent >= 25 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }
}
