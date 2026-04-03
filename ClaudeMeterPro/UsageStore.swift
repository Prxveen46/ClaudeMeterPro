import Foundation
import Combine

@MainActor
class UsageStore: ObservableObject {
    @Published var usageInfo: UsageInfo?
    @Published var lastError: String?
    @Published var isLoading = false
    @Published var hasSessionKey: Bool = false
    @Published var menuBarLabel: String = "—"

    // Predictions
    @Published var sessionPrediction: String?
    @Published var dailyPrediction: String?
    @Published var weeklyPrediction: String?

    @Published var menuBarStyle: String {
        didSet {
            UserDefaults.standard.set(menuBarStyle, forKey: "menuBarStyle")
            // Force menu bar label refresh so .id() triggers re-render
            updateMenuBarLabel()
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

    /// Live countdown text, ticked every second by a dedicated timer.
    @Published var countdownText: String = "--"

    private let webClient = ClaudeAPIClient()
    private var pollTimer: Timer?
    private var countdownTimer: Timer?
    private var retryTimer: Timer?
    private var consecutiveFailures = 0

    // Track last label to avoid unnecessary SwiftUI updates
    private var lastComputedLabel: String = "—"

    private static let resetTimeFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt
    }()

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
        consecutiveFailures = 0
        webClient.resetReadyState()
        stopPolling()
        updateMenuBarLabel()
    }

    // MARK: - Fetching

    func fetchUsage() async {
        guard !isLoading else { return }  // prevent concurrent fetches
        isLoading = true
        lastError = nil
        retryTimer?.invalidate()
        retryTimer = nil
        updateMenuBarLabel()

        // Retry up to 3 times with 5s delays for transient failures
        var attempts = 0
        let maxAttempts = 3
        var lastAttemptError: String?

        while attempts < maxAttempts {
            attempts += 1
            do {
                let info = try await webClient.fetchUsage()
                let previousInfo = self.usageInfo
                self.usageInfo = info

                // Record to history database
                await UsageHistoryStore.shared.recordSnapshot(info)

                // Check notification thresholds
                let countdown = formatCountdown(info.sessionResetDate.map { max(0, $0.timeIntervalSinceNow) } ?? 0)
                NotificationManager.shared.checkAndNotify(previous: previousInfo, current: info, countdown: countdown)

                // Update predictions
                await updatePredictions(info)

                self.consecutiveFailures = 0
                lastAttemptError = nil
                break
            } catch let error as APIError {
                lastAttemptError = error.localizedDescription
                // Don't retry auth errors — they won't self-resolve
                if case .noSessionKey = error { break }
                if case .parseError(let msg) = error, msg.contains("expired") { break }
                // Retry transient errors
                if attempts < maxAttempts {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                }
            } catch {
                lastAttemptError = error.localizedDescription
                if attempts < maxAttempts {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }

        if let errorMsg = lastAttemptError {
            self.lastError = errorMsg
            self.consecutiveFailures += 1

            // If we still have no data, schedule a quick retry (10s)
            // to avoid waiting the full poll interval
            if usageInfo == nil && consecutiveFailures < 6 {
                scheduleQuickRetry()
            }
        }

        isLoading = false
        updateMenuBarLabel()
    }

    private func scheduleQuickRetry() {
        retryTimer?.invalidate()
        let delay: TimeInterval = min(Double(consecutiveFailures) * 10, 60) // 10s, 20s, 30s... max 60s
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { await self.fetchUsage() }
        }
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

        // If we have data, always show it (even if last fetch failed — data is still valid)
        if let info = usageInfo {
            let percent = "\(info.usagePercentInt)%"
            let countdown = formatCountdown(resetSecondsRemaining)
            return "\(percent) | \(countdown)"
        }

        // No data yet
        if isLoading || retryTimer != nil { return "..." }
        if lastError != nil { return "⚠ Error" }
        return "—"
    }

    var resetSecondsRemaining: TimeInterval {
        guard let date = sessionResetDate else { return 0 }
        return max(0, date.timeIntervalSinceNow)
    }

    /// Absolute reset time formatted as "2:30 PM" — shown when usage hits 100%.
    var resetTimeFormatted: String? {
        guard let date = sessionResetDate, date.timeIntervalSinceNow > 0 else { return nil }
        return Self.resetTimeFmt.string(from: date)
    }

    /// Whether usage is fully exhausted.
    var isExhausted: Bool {
        (usageInfo?.usagePercentInt ?? 0) >= 100
    }

    // MARK: - Polling

    /// Called by SettingsView after validation succeeds.
    func startPollingIfNeeded() {
        guard hasSessionKey, pollTimer == nil else { return }
        startPolling()
    }

    private func startPolling() {
        stopPolling()
        Task { await fetchUsage() }

        pollTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.fetchUsage() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func restartPolling() {
        guard hasSessionKey else { return }
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.fetchUsage() }
        }
    }

    // MARK: - Countdown (1-second tick for live display)

    func startCountdown() {
        stopCountdown()
        tickCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.tickCountdown() }
        }
    }

    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func tickCountdown() {
        countdownText = formatCountdown(resetSecondsRemaining)
        updateMenuBarLabel()
    }

    // MARK: - Login Item (LaunchAgent plist)

    private static let launchAgentLabel = "com.claudemeter.pro"
    private static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    private func updateLoginItem() {
        let plistURL = Self.launchAgentURL
        if launchAtLogin {
            // Resolve the current executable path
            let execPath = ProcessInfo.processInfo.arguments.first
                ?? Bundle.main.executablePath
                ?? "/usr/local/bin/ClaudeMeterPro"

            let plist: [String: Any] = [
                "Label": Self.launchAgentLabel,
                "ProgramArguments": [execPath],
                "RunAtLoad": true,
                "KeepAlive": false,
            ]

            let data = try? PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0
            )
            FileManager.default.createFile(atPath: plistURL.path, contents: data)
        } else {
            try? FileManager.default.removeItem(at: plistURL)
        }
    }

    // MARK: - Predictions

    private func updatePredictions(_ info: UsageInfo) async {
        let recent = await UsageHistoryStore.shared.recentSnapshots(minutesBack: 30)

        sessionPrediction = UsagePredictionEngine.predict(
            snapshots: recent, currentPercent: info.sessionPercent
        )?.formatted

        if let daily = info.daily {
            dailyPrediction = UsagePredictionEngine.predictTier(
                snapshots: recent, currentPercent: daily.percent, tierKeyPath: \.dailyPercent
            )?.formatted
        } else {
            dailyPrediction = nil
        }

        if let weekly = info.weekly {
            weeklyPrediction = UsagePredictionEngine.predictTier(
                snapshots: recent, currentPercent: weekly.percent, tierKeyPath: \.weeklyPercent
            )?.formatted
        } else {
            weeklyPrediction = nil
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
