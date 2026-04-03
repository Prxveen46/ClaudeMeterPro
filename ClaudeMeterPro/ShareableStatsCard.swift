import SwiftUI
import AppKit

/// Generates a branded image card of current usage stats for sharing.
struct ShareableStatsCard: View {
    let usageInfo: UsageInfo
    let countdown: String

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(LinearGradient(
                        colors: [ClaudeTheme.amberLight, ClaudeTheme.amber],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                Text("ClaudeMeter Pro")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(countdown)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Main percentage
            HStack(alignment: .firstTextBaseline) {
                Text("\(usageInfo.usagePercentInt)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(ClaudeTheme.usageColor(percent: usageInfo.usagePercentInt))
                Text("%")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(ClaudeTheme.usageColor(percent: usageInfo.usagePercentInt).opacity(0.5))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("5-HOUR SESSION")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.5)
                    barPreview(percent: usageInfo.usagePercentInt)
                }
            }

            // Tier bars
            HStack(spacing: 12) {
                if let daily = usageInfo.daily {
                    tierColumn(label: "Daily", percent: daily.percentInt)
                }
                if let weekly = usageInfo.weekly {
                    tierColumn(label: "Weekly", percent: weekly.percentInt)
                }
                Spacer()
            }

            // Footer
            HStack {
                Text("claude.ai usage tracker")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
                Text("prxveen.work")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ClaudeTheme.amber.opacity(0.6))
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(ClaudeTheme.amber.opacity(0.15), lineWidth: 1)
        )
    }

    private func barPreview(percent: Int) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(width: 80, height: 6)
            Capsule()
                .fill(ClaudeTheme.usageColor(percent: percent))
                .frame(width: max(0, 80 * CGFloat(percent) / 100), height: 6)
        }
    }

    private func tierColumn(label: String, percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(0.5)
            HStack(spacing: 6) {
                barPreview(percent: percent)
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ClaudeTheme.usageColor(percent: percent))
            }
        }
    }
}

// MARK: - Render & Share

extension ShareableStatsCard {
    /// Render the card to an NSImage and copy to clipboard + optionally save.
    @MainActor
    static func share(usageInfo: UsageInfo, countdown: String) {
        let card = ShareableStatsCard(usageInfo: usageInfo, countdown: countdown)
        let hosting = NSHostingView(rootView: card)
        hosting.frame = NSRect(x: 0, y: 0, width: 360, height: 240)

        // Force layout
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        let image = NSImage(size: size)
        image.addRepresentation(rep)

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        // Also offer save dialog
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "ClaudeMeterPro-Stats.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: url)
        }
    }
}
