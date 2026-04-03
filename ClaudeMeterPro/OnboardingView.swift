import SwiftUI

/// First-launch onboarding wizard shown once.
struct OnboardingView: View {
    @ObservedObject var usageStore: UsageStore
    @State private var step = 0
    @State private var sessionKeyText = ""
    @State private var isValidating = false
    @State private var validationMessage: String?
    var onComplete: () -> Void

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? ClaudeTheme.amber : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 20)

            Spacer()

            // Step content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: sessionKeyStep
                case 2: doneStep
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            // Navigation
            HStack {
                if step > 0 && step < totalSteps - 1 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.3)) { step -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if step == 0 {
                    Button("Get Started") {
                        withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClaudeTheme.amber)
                } else if step == totalSteps - 1 {
                    Button("Start Using ClaudeMeter Pro") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClaudeTheme.amber)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(width: 460, height: 400)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ClaudeTheme.amber.opacity(0.2), Color.clear],
                            center: .center, startRadius: 20, endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(LinearGradient(
                        colors: [ClaudeTheme.amberLight, ClaudeTheme.amber],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                    .shadow(color: ClaudeTheme.amber.opacity(0.3), radius: 12, y: 4)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Welcome to ClaudeMeter Pro")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Track your Claude.ai usage right from the menu bar.\nSession, daily, and weekly limits at a glance.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 32)
        }
    }

    private var sessionKeyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect Your Account")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 10) {
                stepInstruction(number: "1", text: "Open claude.ai in your browser and sign in")
                stepInstruction(number: "2", text: "Open Developer Tools (Cmd+Option+I)")
                stepInstruction(number: "3", text: "Go to Application → Cookies → claude.ai")
                stepInstruction(number: "4", text: "Copy the \"sessionKey\" cookie value")
            }
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                SecureField("Paste session key...", text: $sessionKeyText)
                    .textFieldStyle(.roundedBorder)

                Button(isValidating ? "Checking..." : "Connect") {
                    validateKey()
                }
                .buttonStyle(.borderedProminent)
                .tint(ClaudeTheme.amber)
                .disabled(sessionKeyText.isEmpty || isValidating)
            }
            .padding(.horizontal, 12)

            if let msg = validationMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(msg.contains("✓") ? .green : .red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 20)
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ClaudeTheme.amber.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ClaudeTheme.amber)
            }

            Text("You're All Set!")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            VStack(spacing: 6) {
                tipRow(icon: "keyboard", text: "Cmd+Shift+U to toggle the popover")
                tipRow(icon: "bell.fill", text: "Get alerts at 75%, 90%, and 100% usage")
                tipRow(icon: "chart.xyaxis.line", text: "View history in Settings → History tab")
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Helpers

    private func stepInstruction(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(ClaudeTheme.amber))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ClaudeTheme.amber)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func validateKey() {
        isValidating = true
        validationMessage = nil

        let success = KeychainHelper.save(apiKey: sessionKeyText)
        usageStore.hasSessionKey = success && !sessionKeyText.isEmpty

        Task {
            await usageStore.fetchUsage()
            isValidating = false
            if usageStore.usageInfo != nil {
                validationMessage = "✓ Connected successfully!"
                usageStore.startPollingIfNeeded()
                // Auto-advance after success
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation(.easeInOut(duration: 0.3)) { step = 2 }
            } else {
                validationMessage = "✗ \(usageStore.lastError ?? "Connection failed")"
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        onComplete()
    }
}

// MARK: - Onboarding Window Controller

class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: "onboardingCompleted")
    }

    func show(usageStore: UsageStore) {
        guard window == nil else { return }

        let onboarding = OnboardingView(usageStore: usageStore) { [weak self] in
            self?.window?.close()
            self?.window = nil
        }
        let hosting = NSHostingView(rootView: onboarding)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to ClaudeMeter Pro"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating

        self.window = window

        NSApp.setActivationPolicy(.accessory)
        window.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
