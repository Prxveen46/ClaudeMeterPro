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

// MARK: - Menu Bar Label (switches on icon style)

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        let percent = store.usageInfo?.sessionPercentInt ?? 0
        let label = store.menuBarLabel

        switch store.menuBarStyle {
        case "battery":
            HStack(spacing: 4) {
                MenuBarBattery(percent: percent)
                Text("\(percent)%")
                    .monospacedDigit()
                    .font(.caption2)
            }
        case "circular":
            HStack(spacing: 4) {
                MenuBarCircular(percent: percent)
                Text(label)
                    .monospacedDigit()
                    .font(.caption2)
            }
        case "segments":
            HStack(spacing: 4) {
                MenuBarSegments(percent: percent)
                Text(label)
                    .monospacedDigit()
                    .font(.caption2)
            }
        case "dualbar":
            HStack(spacing: 4) {
                MenuBarDualBar(percent: percent)
                Text("\(percent)%")
                    .monospacedDigit()
                    .font(.caption2)
            }
        case "gauge":
            HStack(spacing: 4) {
                Image(systemName: gaugeIcon(percent))
                Text(label)
                    .monospacedDigit()
                    .font(.caption2)
            }
        default: // "minimal"
            Text(label)
                .monospacedDigit()
        }
    }

    private func gaugeIcon(_ percent: Int) -> String {
        if percent >= 80 { return "gauge.with.dots.needle.100percent" }
        if percent >= 50 { return "gauge.with.dots.needle.67percent" }
        if percent >= 20 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }
}

// MARK: - Menu Bar Icon Components (all white/primary, no colors)

struct MenuBarBattery: View {
    let percent: Int

    var body: some View {
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
    }
}

struct MenuBarCircular: View {
    let percent: Int

    var body: some View {
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
    }
}

struct MenuBarSegments: View {
    let percent: Int

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(i < Int(Double(percent) / 20) ? Color.white : Color.white.opacity(0.2))
                    .frame(width: 3, height: CGFloat(5 + i * 2))
            }
        }
    }
}

struct MenuBarDualBar: View {
    let percent: Int

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.2))
                .frame(width: 22, height: 6)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white)
                .frame(width: max(1, CGFloat(percent) / 100 * 22), height: 6)
        }
    }
}
