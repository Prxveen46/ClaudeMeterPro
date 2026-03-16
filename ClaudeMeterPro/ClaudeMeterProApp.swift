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

    // Icons reflect usage consumed: low % = calm, high % = warning
    private var energyIcon: String {
        // 15% used = low drain, 90% used = critical
        if pct >= 75 { return "bolt.slash.fill" }        // critical — almost depleted
        if pct >= 50 { return "bolt.trianglebadge.exclamationmark.fill" } // warning
        if pct >= 25 { return "bolt" }                    // moderate use
        return "bolt.fill"                                // barely used — full energy
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
        if pct >= 75 { return "circle.fill" }             // almost full usage
        if pct >= 50 { return "circle.bottomhalf.filled" }
        if pct >= 25 { return "circle.lefthalf.filled" }
        if pct > 0  { return "circle.bottomthird.split" } // small slice used
        return "circle"                                    // nothing used
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
        if pct >= 60 { return "chart.bar.fill" }          // high usage
        if pct >= 30 { return "chart.bar.xaxis" }
        return "chart.bar"                                 // low usage
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
        if pct >= 75 { return "rectangle.fill" }           // nearly full usage
        if pct >= 50 { return "rectangle.leadinghalf.filled" }
        if pct >= 25 { return "rectangle.trailinghalf.filled" }
        return "rectangle"                                  // barely used
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
        if pct >= 75 { return "gauge.with.dots.needle.100percent" }
        if pct >= 50 { return "gauge.with.dots.needle.67percent" }
        if pct >= 25 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"            // needle low
    }
}
