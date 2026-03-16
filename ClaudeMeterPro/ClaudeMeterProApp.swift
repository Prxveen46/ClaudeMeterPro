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

    // MARK: - Battery
    // SF Symbols: battery.0, battery.25, battery.50, battery.75, battery.100
    private var batteryLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: batteryIcon)
                .font(.system(size: 16))
            Text("\(pct)%  \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var batteryIcon: String {
        if pct >= 88 { return "battery.100" }
        if pct >= 63 { return "battery.75" }
        if pct >= 38 { return "battery.50" }
        if pct >= 13 { return "battery.25" }
        return "battery.0"
    }

    // MARK: - Circular
    // SF Symbols: circle.dashed, circle.bottomhalf.filled, circle.lefthalf.filled, etc.
    private var circularLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: circularIcon)
                .font(.system(size: 13))
            Text("\(pct)%  \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var circularIcon: String {
        if pct >= 88 { return "circle.fill" }
        if pct >= 63 { return "circle.bottomhalf.filled" }
        if pct >= 38 { return "circle.lefthalf.filled" }
        if pct >= 13 { return "circle.bottomthird.split" }
        return "circle"
    }

    // MARK: - Segments
    // SF Symbols: chart.bar, chart.bar.fill
    private var segmentsLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: segmentsIcon)
                .font(.system(size: 13))
            Text("\(pct)%  \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var segmentsIcon: String {
        if pct >= 60 { return "chart.bar.fill" }
        if pct >= 30 { return "chart.bar.xaxis" }
        return "chart.bar"
    }

    // MARK: - Dual Bar
    // SF Symbols: line/rectangle based progress
    private var dualBarLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: dualBarIcon)
                .font(.system(size: 13))
            Text("\(pct)%  \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var dualBarIcon: String {
        if pct >= 75 { return "rectangle.fill" }
        if pct >= 50 { return "rectangle.leadinghalf.filled" }
        if pct >= 25 { return "rectangle.trailinghalf.filled" }
        return "rectangle"
    }

    // MARK: - Gauge
    private var gaugeLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: gaugeIcon)
                .font(.system(size: 13))
            Text("\(pct)%  \(tmr)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    private var gaugeIcon: String {
        if pct >= 75 { return "gauge.with.dots.needle.100percent" }
        if pct >= 50 { return "gauge.with.dots.needle.67percent" }
        if pct >= 25 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }
}
