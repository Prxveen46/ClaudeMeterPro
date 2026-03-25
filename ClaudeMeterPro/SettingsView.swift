import SwiftUI

// MARK: - Settings Window

struct SettingsView: View {
    @ObservedObject var usageStore: UsageStore
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)

            Divider()
                .padding(.top, 8)

            ScrollView {
                switch selectedTab {
                case .general:
                    GeneralTab(usageStore: usageStore)
                case .about:
                    AboutTab()
                }
            }
        }
        .frame(width: 520, height: 600)
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 22)
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? ClaudeTheme.amber : .secondary)
            .frame(width: 80, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? ClaudeTheme.amber.opacity(0.08) : Color.clear)
            )
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

    var body: some View {
        VStack(spacing: 14) {
            // Session Key
            settingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    cardHeader(title: "Session Key", icon: "key.fill")
                    Text("Your Claude.ai session key authenticates API requests. Find this in your browser's cookies.")
                        .font(.system(size: 11))
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
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)

                        Button {
                            sessionKeyText = ""
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .disabled(sessionKeyText.isEmpty)
                    }

                    HStack(spacing: 8) {
                        Button("Validate & Save") {
                            validateAndSave()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ClaudeTheme.amber)
                        .disabled(sessionKeyText.isEmpty || isValidating)

                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        }

                        if let msg = validationMessage {
                            Text(msg)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(msg.contains("✓") ? .green : .red)
                        }
                    }
                }
            }

            // Refresh Interval
            settingsCard {
                HStack {
                    cardHeader(title: "Refresh Interval", icon: "clock.arrow.2.circlepath")
                    Spacer()
                    Picker("", selection: $usageStore.refreshInterval) {
                        Text("1 min").tag(60.0)
                        Text("2 min").tag(120.0)
                        Text("5 min").tag(300.0)
                        Text("10 min").tag(600.0)
                    }
                    .frame(width: 120)
                }
            }

            // Menu Bar Icon Style
            settingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    cardHeader(title: "Menu Bar Style", icon: "menubar.rectangle")
                    Text("Choose how usage appears in your menu bar")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        // New styles
                        ringStyleCard
                        pillStyleCard
                        dotStyleCard
                        // Classic styles
                        iconStyleCard("battery", label: "Energy", icon: "bolt.fill", text: "65% | 2h 30m")
                        iconStyleCard("circular", label: "Circular", icon: "circle.bottomhalf.filled", text: "65% | 2h 30m")
                        iconStyleCard("minimal", label: "Minimal", icon: nil, text: "65% | 2h 30m")
                        iconStyleCard("segments", label: "Segments", icon: "chart.bar.fill", text: "65% | 2h 30m")
                        iconStyleCard("dualbar", label: "Dual Bar", icon: "rectangle.leadinghalf.filled", text: "65% | 2h 30m")
                        iconStyleCard("gauge", label: "Gauge", icon: "gauge.with.dots.needle.67percent", text: "65% | 2h 30m")
                    }
                }
            }

            // Launch at Login
            settingsCard {
                Toggle(isOn: $usageStore.launchAtLogin) {
                    cardHeader(title: "Start at Login", icon: "sunrise.fill")
                }
                .tint(ClaudeTheme.amber)
            }
        }
        .padding(18)
        .onAppear {
            sessionKeyText = KeychainHelper.load() ?? ""
        }
    }

    // MARK: - Card Components

    private func cardHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ClaudeTheme.amber)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private func validateAndSave() {
        isValidating = true
        validationMessage = nil
        usageStore.setSessionKey(sessionKeyText)

        Task {
            await usageStore.fetchUsage()
            isValidating = false
            if usageStore.usageInfo != nil {
                validationMessage = "✓ Connected successfully"
            } else {
                validationMessage = "✗ \(usageStore.lastError ?? "Connection failed")"
            }
        }
    }

    // MARK: - New Style Preview Cards

    private var ringStyleCard: some View {
        styleCard("ring", label: "Ring") {
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 16, height: 16)
                    Circle()
                        .trim(from: 0, to: 0.65)
                        .stroke(ClaudeTheme.amber, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(-90))
                }
                Text("2h 30m")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
            }
        }
    }

    private var pillStyleCard: some View {
        styleCard("pill", label: "Pill") {
            HStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 8)
                    Capsule()
                        .fill(ClaudeTheme.amber)
                        .frame(width: 16, height: 8)
                }
                Text("65%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
            }
        }
    }

    private var dotStyleCard: some View {
        styleCard("dot", label: "Pulse") {
            HStack(spacing: 4) {
                Circle()
                    .fill(ClaudeTheme.amber)
                    .frame(width: 8, height: 8)
                Text("65%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private func styleCard<Content: View>(
        _ style: String,
        label: String,
        @ViewBuilder preview: () -> Content
    ) -> some View {
        let isSelected = usageStore.menuBarStyle == style
        Button {
            usageStore.menuBarStyle = style
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Spacer()
                    preview()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(isSelected ? 0.18 : 0.08))
                        )
                    Spacer()
                }
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                )

                HStack(spacing: 3) {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? ClaudeTheme.amber : .secondary)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(ClaudeTheme.amber)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? ClaudeTheme.amber.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? ClaudeTheme.amber.opacity(0.5) : Color.gray.opacity(0.15),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Icon Style Card (menu bar simulation)

    @ViewBuilder
    private func iconStyleCard(
        _ style: String,
        label: String,
        icon: String?,
        text: String
    ) -> some View {
        let isSelected = usageStore.menuBarStyle == style
        Button {
            usageStore.menuBarStyle = style
        } label: {
            VStack(spacing: 6) {
                // Mini menu bar simulation
                HStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 3) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 10))
                        }
                        Text(text)
                            .font(.system(size: 8.5, weight: .medium, design: icon == nil ? .monospaced : .default))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.primary.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(isSelected ? 0.18 : 0.08))
                    )
                    Spacer()
                }
                .frame(height: 28)
                .background(
                    // Menu bar strip
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                )

                HStack(spacing: 3) {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? ClaudeTheme.amber : .secondary)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(ClaudeTheme.amber)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? ClaudeTheme.amber.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? ClaudeTheme.amber.opacity(0.5) : Color.gray.opacity(0.15),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @State private var glowPhase: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Branded icon with radial glow
            ZStack {
                // Ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ClaudeTheme.amber.opacity(0.2),
                                ClaudeTheme.amber.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ClaudeTheme.amberLight, ClaudeTheme.amber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: ClaudeTheme.amber.opacity(0.3), radius: 12, y: 4)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("ClaudeMeter Pro")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.top, 4)

            Text("v1.0.0")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            Text("Track your Claude.ai session usage\nright from the menu bar.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 12)

            // Divider with brand color
            HStack(spacing: 8) {
                Rectangle()
                    .fill(ClaudeTheme.amber.opacity(0.2))
                    .frame(height: 1)
                Circle()
                    .fill(ClaudeTheme.amber.opacity(0.3))
                    .frame(width: 4, height: 4)
                Rectangle()
                    .fill(ClaudeTheme.amber.opacity(0.2))
                    .frame(height: 1)
            }
            .frame(width: 120)
            .padding(.vertical, 20)

            Link(destination: URL(string: "https://github.com/Prxveen46/ClaudeMeterPro")!) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .medium))
                    Text("View on GitHub")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.08))
                )
            }
            .buttonStyle(.plain)

            SparkleText(text: "Built by Prxveen.work")
                .padding(.top, 10)

            Spacer()
        }
        .padding(20)
    }
}

// MARK: - Sparkle Hover Text

struct SparkleText: View {
    let text: String

    @State private var isHovered = false
    @State private var sparkles: [(id: Int, x: CGFloat, y: CGFloat, delay: Double)] = []

    var body: some View {
        ZStack {
            // Sparkle particles
            ForEach(sparkles, id: \.id) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat.random(in: 6...10)))
                    .foregroundStyle(ClaudeTheme.amber)
                    .offset(x: sparkle.x, y: sparkle.y)
                    .opacity(isHovered ? 1 : 0)
                    .scaleEffect(isHovered ? 1 : 0.2)
                    .animation(
                        .easeOut(duration: 0.5)
                        .delay(sparkle.delay)
                        .repeatForever(autoreverses: true),
                        value: isHovered
                    )
            }

            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(
                    isHovered
                        ? AnyShapeStyle(ClaudeTheme.amber)
                        : AnyShapeStyle(.tertiary)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.25)) {
                isHovered = hovering
            }
        }
        .onAppear {
            // Pre-generate sparkle positions around the text
            sparkles = (0..<8).map { i in
                let angle = Double(i) / 8.0 * .pi * 2
                let radius: CGFloat = CGFloat.random(in: 30...55)
                return (
                    id: i,
                    x: cos(angle) * radius,
                    y: sin(angle) * radius,
                    delay: Double(i) * 0.07
                )
            }
        }
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
            Self.activateApp()
            return
        }

        let settingsView = SettingsView(usageStore: usageStore)
        let hosting = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClaudeMeter Pro — Settings"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .normal

        self.window = window

        NSApp.setActivationPolicy(.accessory)
        window.makeKeyAndOrderFront(nil)
        Self.activateApp()
    }

    private static func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        // Keep window in memory for reuse
    }
}
