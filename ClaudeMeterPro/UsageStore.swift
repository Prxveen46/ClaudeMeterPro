import Foundation
import Combine
import ServiceManagement

@MainActor
class UsageStore: ObservableObject {
    @Published var usageInfo: UsageInfo?
    @Published var lastError: String?
    @Published var isLoading = false
    @Published var hasSessionKey: Bool = false
    @Published var menuBarLabel: String = "—"

    @Published var menuBarStyle: String {
        didSet {
            UserDefaults.standard.set(menuBarStyle, forKey: "menuBarStyle")
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            restartPolling()
        }
    }

    // Absolute reset date — countdown computed on demand, no persistent timer
    var sessionResetDate: Date? { usageInfo?.sessionResetDate }

    private let webClient = ClaudeWebClient()
    private var pollTimer: Timer?

    // Track last label to avoid unnecessary SwiftUI updates
    private var lastComputedLabel: String = "—"

    init() {
        let saved = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = saved > 0 ? saved : 120
        self.menuBarStyle = UserDefaults.standard.string(forKey: "menuBarStyle") ?? "minimal"
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.hasSessionKey = KeychainHelper.load() != nil

        if hasSessionKey {
            startPolling()
        }
    }

    // MARK: - Key Management

    func setSessionKey(_ key: String) {
        let success = KeychainHelper.save(apiKey: key)
        hasSessionKey = success && !key.isEmpty
        if hasSessionKey {
            startPolling()
        }
    }

    func clearSessionKey() {
        _ = KeychainHelper.delete()
        hasSessionKey = false
        usageInfo = nil
        lastError = nil
        stopPolling()
        updateMenuBarLabel()
    }

    // MARK: - Fetching

    func fetchUsage() async {
        guard !isLoading else { return }  // prevent concurrent fetches
        isLoading = true
        lastError = nil

        do {
            let info = try await webClient.fetchUsage()
            self.usageInfo = info
        } catch {
            self.lastError = error.localizedDescription
        }

        isLoading = false
        updateMenuBarLabel()
    }

    // MARK: - Menu Bar Label

    func updateMenuBarLabel() {
        let label = computeMenuBarLabel()
        if label != lastComputedLabel {
            lastComputedLabel = label
            menuBarLabel = label
        }
    }

    private func computeMenuBarLabel() -> String {
        guard hasSessionKey else { return "⚠ Setup" }
        guard let info = usageInfo else {
            if isLoading { return "..." }
            if lastError != nil { return "⚠ Error" }
            return "—"
        }

        let percent = "\(info.sessionPercentInt)%"
        let countdown = formatCountdown(resetSecondsRemaining)
        return "\(percent) | \(countdown)"
    }

    var resetSecondsRemaining: TimeInterval {
        guard let date = sessionResetDate else { return 0 }
        return max(0, date.timeIntervalSinceNow)
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        Task { await fetchUsage() }

        pollTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.fetchUsage() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func restartPolling() {
        guard hasSessionKey else { return }
        // Don't re-fetch immediately on interval change — next poll will use new interval
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.fetchUsage() }
        }
    }

    // MARK: - Formatting

    // MARK: - Login Item

    private func updateLoginItem() {
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    // MARK: - Formatting

    func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total <= 0 { return "--" }

        let h = total / 3600
        let m = (total % 3600) / 60

        if h > 0 {
            return "\(h)h \(m)m"
        }
        let s = total % 60
        if m > 0 {
            return "\(m)m \(s)s"
        }
        return "\(s)s"
    }
}
