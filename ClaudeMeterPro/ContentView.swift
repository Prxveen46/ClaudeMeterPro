import SwiftUI

struct ContentView: View {
    @ObservedObject var usageStore: UsageStore

    @State private var animatedPercent: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if !usageStore.hasSessionKey {
                setupView
            } else if let error = usageStore.lastError, usageStore.usageInfo == nil {
                errorView(error)
            } else {
                mainView
            }
        }
        .frame(width: 280)
        .onAppear { usageStore.startCountdown() }
        .onDisappear { usageStore.stopCountdown() }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(ClaudeTheme.amber.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ClaudeTheme.amber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClaudeMeter Pro")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Set up your session key to get started.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Open Settings") {
                SettingsWindowController.shared.open(usageStore: usageStore)
            }
            .buttonStyle(.borderedProminent)
            .tint(ClaudeTheme.amber)
            .controlSize(.regular)

            Divider()
            quitButton
        }
        .padding(16)
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                Text("Connection Error")
                    .font(.system(size: 13, weight: .semibold))
            }

            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Button("Retry") {
                Task { await usageStore.fetchUsage() }
            }
            .buttonStyle(.borderedProminent)
            .tint(ClaudeTheme.amber)
            .controlSize(.small)

            Divider()
            quitButton
        }
        .padding(16)
    }

    // MARK: - Main View

    private var mainView: some View {
        VStack(spacing: 0) {
            if let info = usageStore.usageInfo {
                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(info.sessionPercentInt)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ClaudeTheme.usageColor(percent: info.sessionPercentInt))
                        Text("%")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(ClaudeTheme.usageColor(percent: info.sessionPercentInt).opacity(0.5))
                        Spacer()
                        countdownBadge
                    }

                    progressBar(percent: info.sessionPercentInt)

                    Text("5-hour session usage")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                        animatedPercent = CGFloat(info.sessionPercentInt)
                    }
                }
                .onChange(of: info.sessionPercentInt) { newVal in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        animatedPercent = CGFloat(newVal)
                    }
                }
            } else if usageStore.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 0) {
                ToolbarButton(icon: "gearshape", label: "Settings") {
                    SettingsWindowController.shared.open(usageStore: usageStore)
                }
                Spacer()
                ToolbarButton(icon: "arrow.clockwise", label: "Refresh") {
                    Task { await usageStore.fetchUsage() }
                }
                .opacity(usageStore.isLoading ? 0.4 : 1)
                .disabled(usageStore.isLoading)
                Spacer()
                ToolbarButton(icon: "power", label: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Countdown Badge

    private var countdownBadge: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("RESETS IN")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

            Text(usageStore.countdownText)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress Bar

    private func progressBar(percent: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.1))

                Capsule()
                    .fill(ClaudeTheme.usageGradient(percent: percent))
                    .frame(width: max(0, geo.size.width * animatedPercent / 100))
                    .shadow(
                        color: ClaudeTheme.usageColor(percent: percent).opacity(0.45),
                        radius: 6, x: 0, y: 0
                    )

                if animatedPercent > 2 {
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .blur(radius: 2)
                        .offset(x: max(0, geo.size.width * animatedPercent / 100 - 6))
                }
            }
        }
        .frame(height: 8)
    }

    // MARK: - Quit

    private var quitButton: some View {
        ToolbarButton(icon: "power", label: "Quit") {
            NSApplication.shared.terminate(nil)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - Toolbar Button with Hover

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundStyle(isHovered ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? Color.gray.opacity(0.12) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
