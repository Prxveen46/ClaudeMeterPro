import SwiftUI

struct ContentView: View {
    @ObservedObject var usageStore: UsageStore

    // Local countdown timer — only ticks while popover is visible
    @State private var countdownText: String = "--"
    @State private var countdownTimer: Timer?

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
        .frame(width: 260)
        .onAppear { startCountdown() }
        .onDisappear { stopCountdown() }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ClaudeMeter Pro")
                .font(.headline)
            Text("Set up your session key to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Open Settings") {
                SettingsWindowController.shared.open(usageStore: usageStore)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Divider()
            quitButton
        }
        .padding(16)
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await usageStore.fetchUsage() }
            }
            .buttonStyle(.borderedProminent)
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
                VStack(spacing: 12) {
                    // Big percentage + reset timer
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(info.sessionPercentInt)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(percentColor(info.sessionPercentInt))
                        Text("%")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(percentColor(info.sessionPercentInt).opacity(0.6))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("resets in")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(countdownText)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.gray.opacity(0.15))
                            RoundedRectangle(cornerRadius: 5)
                                .fill(barGradient(percent: info.sessionPercentInt))
                                .frame(width: max(0, geo.size.width * CGFloat(info.sessionPercentInt) / 100))
                        }
                    }
                    .frame(height: 10)

                    Text("5-hour session usage")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            } else if usageStore.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }

            Divider()

            // Bottom bar
            HStack {
                Button {
                    SettingsWindowController.shared.open(usageStore: usageStore)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer()

                quitButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Countdown (only when visible)

    private func startCountdown() {
        updateCountdownText()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                updateCountdownText()
                usageStore.updateMenuBarLabel()
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateCountdownText() {
        countdownText = usageStore.formatCountdown(usageStore.resetSecondsRemaining)
    }

    // MARK: - Helpers

    private func percentColor(_ percent: Int) -> Color {
        if percent >= 90 { return .red }
        return .primary
    }

    private func barGradient(percent: Int) -> LinearGradient {
        let color: Color = percent >= 90 ? .red : percent >= 70 ? .orange : .blue
        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var quitButton: some View {
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .font(.caption)
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}
