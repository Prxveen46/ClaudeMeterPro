import SwiftUI
import AppKit
import Darwin

/// File descriptor kept alive for the entire process so the lock is held until exit.
private let singleInstanceFD: CInt = {
    let lockPath = NSTemporaryDirectory() + "ClaudeMeterPro.lock"
    let fd = open(lockPath, O_CREAT | O_WRONLY, 0o600)
    guard fd != -1, flock(fd, LOCK_EX | LOCK_NB) == 0 else {
        exit(0)
    }
    return fd
}()

@main
struct ClaudeMeterProApp: App {
    @StateObject private var usageStore = UsageStore()

    init() {
        _ = singleInstanceFD
        DispatchQueue.main.async {
            NSApp?.setActivationPolicy(.accessory)
        }
    }

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

    private var pct: Int { store.usageInfo?.sessionPercentInt ?? 0 }
    private var hasData: Bool { store.usageInfo != nil }

    private var timeDisplay: String {
        if store.isExhausted, let resetTime = store.resetTimeFormatted {
            return resetTime
        }
        return store.formatCountdown(store.resetSecondsRemaining)
    }

    private var displayText: String { "\(pct)% | \(timeDisplay)" }

    var body: some View {
        if !store.hasSessionKey {
            Label("Setup", systemImage: "exclamationmark.triangle")
        } else if !hasData {
            Text(store.menuBarLabel).monospacedDigit()
        } else if store.isExhausted {
            iconLabel(systemName: "clock.badge.exclamationmark", size: 12)
        } else {
            switch store.menuBarStyle {
            case "battery":   iconLabel(systemName: energyIcon, size: 12)
            case "circular":  iconLabel(systemName: circularIcon)
            case "segments":  iconLabel(systemName: segmentsIcon)
            case "dualbar":   iconLabel(systemName: dualBarIcon)
            case "gauge":     iconLabel(systemName: gaugeIcon)
            case "ring":      ringLabel
            case "pill":      pillLabel
            case "dot":       dotLabel
            default:          minimalLabel
            }
        }
    }

    // MARK: - Shared icon+text label

    private func iconLabel(systemName: String, size: CGFloat = 13) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.system(size: size))
            Text(displayText)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    // MARK: - Minimal (text only)

    private var minimalLabel: some View {
        Text(displayText)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
    }

    // MARK: - Mini Ring (rendered as NSImage for menu bar compatibility)

    private var ringLabel: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcons.ring(percent: pct))
            Text(timeDisplay)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    // MARK: - Fill Pill (rendered as NSImage)

    private var pillLabel: some View {
        HStack(spacing: 5) {
            Image(nsImage: MenuBarIcons.pill(percent: pct))
            Text(displayText)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Breathing Dot (rendered as NSImage)

    private var dotLabel: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcons.dot(percent: pct))
            Text(displayText)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
    }

    // MARK: - Icon resolvers

    private var energyIcon: String {
        if pct >= 75 { return "bolt.slash.fill" }
        if pct >= 50 { return "bolt.trianglebadge.exclamationmark.fill" }
        if pct >= 25 { return "bolt" }
        return "bolt.fill"
    }

    private var circularIcon: String {
        if pct >= 75 { return "circle.fill" }
        if pct >= 50 { return "circle.bottomhalf.filled" }
        if pct >= 25 { return "circle.lefthalf.filled" }
        if pct > 0  { return "circle.bottomthird.split" }
        return "circle"
    }

    private var segmentsIcon: String {
        if pct >= 60 { return "chart.bar.fill" }
        if pct >= 30 { return "chart.bar.xaxis" }
        return "chart.bar"
    }

    private var dualBarIcon: String {
        if pct >= 75 { return "rectangle.fill" }
        if pct >= 50 { return "rectangle.leadinghalf.filled" }
        if pct >= 25 { return "rectangle.trailinghalf.filled" }
        return "rectangle"
    }

    private var gaugeIcon: String {
        if pct >= 75 { return "gauge.with.dots.needle.100percent" }
        if pct >= 50 { return "gauge.with.dots.needle.67percent" }
        if pct >= 25 { return "gauge.with.dots.needle.33percent" }
        return "gauge.with.dots.needle.0percent"
    }
}

// MARK: - Menu Bar Icon Renderer (CGContext → NSImage for reliable menu bar display)

enum MenuBarIcons {
    /// Resolves a ClaudeTheme usage color to NSColor for CoreGraphics drawing.
    private static func nsUsageColor(percent: Int) -> NSColor {
        NSColor(ClaudeTheme.usageColor(percent: percent))
    }

    /// Mini ring: circular progress arc.
    static func ring(percent: Int) -> NSImage {
        let size: CGFloat = 18
        let lineWidth: CGFloat = 2.5
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = (size - lineWidth) / 2

            // Track
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            NSColor.gray.withAlphaComponent(0.3).setStroke()
            track.stroke()

            // Fill arc (from 12 o'clock, clockwise)
            if percent > 0 {
                let startAngle: CGFloat = 90  // 12 o'clock in flipped=false
                let endAngle = startAngle - CGFloat(min(percent, 100)) / 100 * 360
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                nsUsageColor(percent: percent).setStroke()
                arc.stroke()
            }

            return true
        }
        img.isTemplate = false
        return img
    }

    /// Fill pill: capsule that fills proportionally.
    static func pill(percent: Int) -> NSImage {
        let width: CGFloat = 30
        let height: CGFloat = 10
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let radius = height / 2

            // Track
            let trackPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            NSColor.gray.withAlphaComponent(0.25).setFill()
            trackPath.fill()

            // Fill
            let fillWidth = max(height, width * CGFloat(min(percent, 100)) / 100)
            let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)
            nsUsageColor(percent: percent).setFill()
            fillPath.fill()

            return true
        }
        img.isTemplate = false
        return img
    }

    /// Colored dot (solid circle, no animation — animation not supported in menu bar).
    static func dot(percent: Int) -> NSImage {
        let size: CGFloat = 10
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let dotRect = rect.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(ovalIn: dotRect)
            nsUsageColor(percent: percent).setFill()
            path.fill()

            // Subtle outer glow
            let glowPath = NSBezierPath(ovalIn: rect)
            nsUsageColor(percent: percent).withAlphaComponent(0.3).setStroke()
            glowPath.lineWidth = 0.5
            glowPath.stroke()

            return true
        }
        img.isTemplate = false
        return img
    }
}
