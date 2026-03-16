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
            case "battery":   batteryStyle
            case "circular":  circularStyle
            case "segments":  segmentsStyle
            case "dualbar":   dualBarStyle
            case "gauge":     gaugeStyle
            default:          minimalStyle
            }
        }
    }

    // Helper: timer text that's actually visible in menu bar
    private var timerText: Text {
        Text(tmr)
            .font(.system(size: 9))
            .foregroundColor(Color.white.opacity(0.55))
    }

    private var pctText: Text {
        Text("\(pct)%")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
    }

    // MARK: - Minimal
    private var minimalStyle: some View {
        HStack(spacing: 0) {
            Text("\(pct)% | \(tmr)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    // MARK: - Battery (proportional fill using custom drawing)
    private var batteryStyle: some View {
        HStack(spacing: 4) {
            BatteryShape(percent: pct)
                .frame(width: 20, height: 10)
            pctText
            timerText
        }
    }

    // MARK: - Circular (proportional ring)
    private var circularStyle: some View {
        HStack(spacing: 4) {
            CircleProgress(percent: pct)
                .frame(width: 14, height: 14)
            pctText
            timerText
        }
    }

    // MARK: - Segments (proportional bars)
    private var segmentsStyle: some View {
        HStack(spacing: 4) {
            SegmentBars(percent: pct)
                .frame(width: 16, height: 12)
            pctText
            timerText
        }
    }

    // MARK: - Dual Bar (proportional)
    private var dualBarStyle: some View {
        HStack(spacing: 4) {
            BarProgress(percent: pct)
                .frame(width: 24, height: 6)
            pctText
            timerText
        }
    }

    // MARK: - Gauge
    private var gaugeStyle: some View {
        HStack(spacing: 3) {
            Image(systemName: gaugeIcon)
                .font(.system(size: 13))
                .foregroundColor(.white)
            pctText
            timerText
        }
    }

    private var gaugeIcon: String {
        if pct >= 75 { return "gauge.with.dots.needle.100percent" }
        if pct >= 50 { return "gauge.with.dots.needle.67percent" }
        if pct >= 25 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }
}

// MARK: - Custom Menu Bar Shapes (proportional to actual %)

/// Battery icon that fills proportionally
struct BatteryShape: View {
    let percent: Int

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let bodyW = w - 3
            let capW: CGFloat = 2
            let inset: CGFloat = 1.5

            // Battery body outline
            let bodyRect = CGRect(x: 0, y: 0, width: bodyW, height: h)
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: 2)
            context.stroke(bodyPath, with: .color(.white), lineWidth: 1)

            // Fill proportional to percent
            let fillW = max(0, (bodyW - inset * 2) * CGFloat(percent) / 100)
            let fillRect = CGRect(x: inset, y: inset, width: fillW, height: h - inset * 2)
            let fillPath = Path(roundedRect: fillRect, cornerRadius: 1)
            context.fill(fillPath, with: .color(.white))

            // Battery cap
            let capRect = CGRect(x: bodyW + 0.5, y: h * 0.25, width: capW, height: h * 0.5)
            let capPath = Path(roundedRect: capRect, cornerRadius: 0.5)
            context.fill(capPath, with: .color(.white))
        }
    }
}

/// Circular progress ring
struct CircleProgress: View {
    let percent: Int

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 1.5

            // Background ring
            var bgPath = Path()
            bgPath.addArc(center: center, radius: radius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.stroke(bgPath, with: .color(.white.opacity(0.2)), lineWidth: 2)

            // Progress arc
            let end = Angle.degrees(Double(percent) / 100 * 360 - 90)
            var arcPath = Path()
            arcPath.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: end, clockwise: false)
            context.stroke(arcPath, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

/// Signal-style segment bars
struct SegmentBars: View {
    let percent: Int

    var body: some View {
        Canvas { context, size in
            let count = 5
            let gap: CGFloat = 1.5
            let barW = (size.width - gap * CGFloat(count - 1)) / CGFloat(count)
            let filled = Int(Double(percent) / 100 * Double(count - 1)) + (percent > 0 ? 1 : 0)

            for i in 0..<count {
                let barH = size.height * (CGFloat(i + 1) / CGFloat(count))
                let x = CGFloat(i) * (barW + gap)
                let y = size.height - barH
                let rect = CGRect(x: x, y: y, width: barW, height: barH)
                let path = Path(roundedRect: rect, cornerRadius: 0.5)
                let isFilled = i < filled
                context.fill(path, with: .color(.white.opacity(isFilled ? 1 : 0.2)))
            }
        }
    }
}

/// Horizontal progress bar
struct BarProgress: View {
    let percent: Int

    var body: some View {
        Canvas { context, size in
            let h = size.height
            let w = size.width

            // Background
            let bgRect = CGRect(x: 0, y: 0, width: w, height: h)
            let bgPath = Path(roundedRect: bgRect, cornerRadius: h / 2)
            context.fill(bgPath, with: .color(.white.opacity(0.2)))

            // Fill
            let fillW = max(h, w * CGFloat(percent) / 100) // min width = height for rounded caps
            let fillRect = CGRect(x: 0, y: 0, width: fillW, height: h)
            let fillPath = Path(roundedRect: fillRect, cornerRadius: h / 2)
            context.fill(fillPath, with: .color(.white))
        }
    }
}
