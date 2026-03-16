import SwiftUI

@main
struct ClaudeMeterProApp: App {
    @StateObject private var usageStore = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView(usageStore: usageStore)
        } label: {
            MenuBarLabel(store: usageStore)
                .id("mb-\(usageStore.menuBarStyle)-\(usageStore.menuBarLabel)")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    private var pct: Int { store.usageInfo?.sessionPercentInt ?? 0 }
    private var remaining: Int { 100 - pct }  // icons show remaining capacity
    private var tmr: String { store.formatCountdown(store.resetSecondsRemaining) }
    private var hasData: Bool { store.usageInfo != nil }

    var body: some View {
        if !store.hasSessionKey {
            Label("Setup", systemImage: "exclamationmark.triangle")
        } else if !hasData {
            Text(store.menuBarLabel).monospacedDigit()
        } else {
            switch store.menuBarStyle {
            case "battery":   batteryLabel
            case "circular":  circularLabel
            case "segments":  segmentsLabel
            case "dualbar":   dualBarLabel
            case "gauge":     gaugeLabel
            default:          minimalLabel
            }
        }
    }

    // MARK: - Minimal
    private var minimalLabel: some View {
        Text("\(pct)% | \(tmr)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
    }

    // MARK: - Energy (bolt icon — represents remaining energy)
    private var batteryLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: energyIcon)
                .font(.system(size: 12))
            Text("\(pct)% | \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var energyIcon: String {
        if remaining >= 75 { return "bolt.fill" }
        if remaining >= 50 { return "bolt" }
        if remaining >= 25 { return "bolt.trianglebadge.exclamationmark.fill" }
        return "bolt.slash.fill"
    }

    // MARK: - Circular
    private var circularLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: circularIcon)
                .font(.system(size: 13))
            Text("\(pct)% | \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var circularIcon: String {
        if remaining >= 88 { return "circle.fill" }
        if remaining >= 63 { return "circle.bottomhalf.filled" }
        if remaining >= 38 { return "circle.lefthalf.filled" }
        if remaining >= 13 { return "circle.bottomthird.split" }
        return "circle"
    }

    // MARK: - Segments
    private var segmentsLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: segmentsIcon)
                .font(.system(size: 13))
            Text("\(pct)% | \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var segmentsIcon: String {
        if remaining >= 60 { return "chart.bar.fill" }
        if remaining >= 30 { return "chart.bar.xaxis" }
        return "chart.bar"
    }

    // MARK: - Dual Bar
    private var dualBarLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: dualBarIcon)
                .font(.system(size: 13))
            Text("\(pct)% | \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var dualBarIcon: String {
        if remaining >= 75 { return "rectangle.fill" }
        if remaining >= 50 { return "rectangle.leadinghalf.filled" }
        if remaining >= 25 { return "rectangle.trailinghalf.filled" }
        return "rectangle"
    }

    // MARK: - Gauge
    private var gaugeLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: gaugeIcon)
                .font(.system(size: 13))
            Text("\(pct)% | \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var gaugeIcon: String {
        if remaining >= 75 { return "gauge.with.dots.needle.100percent" }
        if remaining >= 50 { return "gauge.with.dots.needle.67percent" }
        if remaining >= 25 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }
}
