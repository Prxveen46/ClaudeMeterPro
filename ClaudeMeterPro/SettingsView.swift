import SwiftUI

// MARK: - Settings Window

struct SettingsView: View {
    @ObservedObject var usageStore: UsageStore
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                ForEach(SettingsTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                switch selectedTab {
                case .general:
                    GeneralTab(usageStore: usageStore)
                case .about:
                    AboutTab()
                }
            }
        }
        .frame(width: 520, height: 580)
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.title2)
                    .frame(height: 24)
                Text(tab.title)
                    .font(.caption)
            }
            .foregroundStyle(selectedTab == tab ? .blue : .secondary)
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, about
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .about: return "info.circle.fill"
        }
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @ObservedObject var usageStore: UsageStore

    @State private var sessionKeyText = ""
    @State private var showKey = false
    @State private var isValidating = false
    @State private var validationMessage: String?

    // Use usageStore.menuBarStyle and usageStore.launchAtLogin directly

    var body: some View {
        VStack(spacing: 16) {
            // Session Key
            settingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Key")
                        .font(.headline)
                    Text("Your Claude.ai session key authenticates API requests. Find this in your browser's cookies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Group {
                            if showKey {
                                TextField("sk-ant-sid...", text: $sessionKeyText)
                            } else {
                                SecureField("sk-ant-sid...", text: $sessionKeyText)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .frame(width: 20)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            sessionKeyText = ""
                        } label: {
                            Image(systemName: "xmark.circle")
                                .frame(width: 20)
                        }
                        .buttonStyle(.borderless)
                        .disabled(sessionKeyText.isEmpty)
                    }

                    HStack {
                        Button("Validate & Save") {
                            validateAndSave()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(sessionKeyText.isEmpty || isValidating)

                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        }

                        if let msg = validationMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(msg.contains("✓") ? .green : .red)
                        }
                    }
                }
            }

            // Refresh Interval
            settingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Refresh Interval")
                            .font(.headline)
                        Text("How often to check your usage data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $usageStore.refreshInterval) {
                        Text("1 minute").tag(60.0)
                        Text("2 minutes").tag(120.0)
                        Text("5 minutes").tag(300.0)
                        Text("10 minutes").tag(600.0)
                    }
                    .frame(width: 140)
                }
            }

            // Menu Bar Icon Style
            settingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Menu Bar Icon Style")
                        .font(.headline)
                    Text("Choose how the usage indicator appears in your menu bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        // Battery
                        iconStyleCard("battery", label: "Battery") {
                            HStack(spacing: 4) {
                                PreviewBattery()
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("65%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("2h 30m")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                        // Circular
                        iconStyleCard("circular", label: "Circular") {
                            HStack(spacing: 4) {
                                PreviewCircular()
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("65%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("2h 30m")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                        // Minimal
                        iconStyleCard("minimal", label: "Minimal") {
                            VStack(spacing: 2) {
                                Text("65% | 2h 30m")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        }
                        // Segments
                        iconStyleCard("segments", label: "Segments") {
                            HStack(spacing: 4) {
                                PreviewSegments()
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("65%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("2h 30m")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                        // Dual Bar
                        iconStyleCard("dualbar", label: "Dual Bar") {
                            HStack(spacing: 4) {
                                PreviewDualBar()
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("65%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("2h 30m")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                        // Gauge
                        iconStyleCard("gauge", label: "Gauge") {
                            HStack(spacing: 4) {
                                Image(systemName: "gauge.with.dots.needle.67percent")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("65%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("2h 30m")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
            }

            // Launch at Login
            settingsCard {
                Toggle(isOn: $usageStore.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start at Login")
                            .font(.headline)
                        Text("Automatically launch ClaudeMeter Pro when you log in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.blue)
            }
        }
        .padding(20)
        .onAppear {
            sessionKeyText = KeychainHelper.load() ?? ""
        }
    }

    // MARK: - Helpers

    private func validateAndSave() {
        isValidating = true
        validationMessage = nil
        usageStore.setSessionKey(sessionKeyText)

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            while usageStore.isLoading {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            isValidating = false
            if usageStore.usageInfo != nil {
                validationMessage = "✓ Connected successfully"
            } else {
                validationMessage = "✗ \(usageStore.lastError ?? "Connection failed")"
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func iconStyleCard<Content: View>(
        _ style: String,
        label: String,
        @ViewBuilder preview: () -> Content
    ) -> some View {
        Button {
            usageStore.menuBarStyle = style
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(usageStore.menuBarStyle == style ? Color.blue.opacity(0.08) : Color.gray.opacity(0.1))
                        .frame(height: 40)
                    preview()
                }
                HStack(spacing: 4) {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(usageStore.menuBarStyle == style ? .blue : .secondary)
                    if usageStore.menuBarStyle == style {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(usageStore.menuBarStyle == style ? Color.blue : Color.gray.opacity(0.2), lineWidth: usageStore.menuBarStyle == style ? 2 : 1)
        )
    }
}

// MARK: - Settings Preview Components (larger, styled versions for the picker)

struct PreviewBattery: View {
    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(Color.white, lineWidth: 1)
                    .frame(width: 28, height: 13)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 17, height: 10) // ~65% of 26
                    .padding(.leading, 1.5)
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white)
                .frame(width: 2.5, height: 6)
        }
    }
}

struct PreviewCircular: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3.5)
                .frame(width: 30, height: 30)
            Circle()
                .trim(from: 0, to: 0.65)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(-90))
            Text("65")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

struct PreviewSegments: View {
    var body: some View {
        HStack(spacing: 3) {
            // 65% = ~3.25 segments filled out of 5
            RoundedRectangle(cornerRadius: 1.5).fill(Color.white).frame(width: 6, height: 10)
            RoundedRectangle(cornerRadius: 1.5).fill(Color.white).frame(width: 6, height: 15)
            RoundedRectangle(cornerRadius: 1.5).fill(Color.white).frame(width: 6, height: 20)
            RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.2)).frame(width: 6, height: 25)
            RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.2)).frame(width: 6, height: 30)
        }
    }
}

struct PreviewDualBar: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 8)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(width: 23, height: 8) // ~65%
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("ClaudeMeter Pro")
                .font(.title2.bold())

            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("A lightweight menu bar app to track\nyour Claude.ai session usage.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("Built with SwiftUI")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(20)
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func open(usageStore: UsageStore) {
        // If window already exists, just bring it forward
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(usageStore: usageStore)
        let hosting = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClaudeMeter Pro — Settings"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating  // Ensure it appears above the menu bar popover

        self.window = window

        // Activate the app so the window can receive focus
        NSApp.setActivationPolicy(.accessory)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Keep window in memory for reuse
    }
}
