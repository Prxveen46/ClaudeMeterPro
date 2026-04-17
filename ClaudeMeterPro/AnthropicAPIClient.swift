import Foundation
import WebKit
import os.log

private let logger = Logger(subsystem: "com.claudemeterpro", category: "APIClient")

// MARK: - Models

struct UsageTier {
    let percent: Double             // 0.0 - 1.0
    let resetDate: Date?            // absolute reset time
    var percentInt: Int { min(100, Int(percent * 100)) }
}

struct UsageInfo {
    let sessionPercent: Double       // 0.0 - 1.0  (5-hour or primary)
    let sessionResetDate: Date?      // absolute reset time

    // Additional tiers (nil if API doesn't return them)
    let daily: UsageTier?
    let weekly: UsageTier?

    var usagePercentInt: Int { min(100, Int(sessionPercent * 100)) }

    init(sessionPercent: Double, sessionResetDate: Date?, daily: UsageTier? = nil, weekly: UsageTier? = nil) {
        self.sessionPercent = sessionPercent
        self.sessionResetDate = sessionResetDate
        self.daily = daily
        self.weekly = weekly
    }
}

enum APIError: Error, LocalizedError {
    case noSessionKey
    case invalidResponse
    case cloudflareBlocked
    case httpError(Int, String)
    case parseError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noSessionKey: return "No session key configured"
        case .invalidResponse: return "Invalid response"
        case .cloudflareBlocked: return "Cloudflare blocked — open claude.ai in Safari, then retry"
        case .httpError(let code, let detail): return "HTTP \(code): \(detail)"
        case .parseError(let msg): return msg
        case .networkError(let err): return err.localizedDescription
        }
    }
}

// MARK: - Hybrid Client (WebView for Cloudflare, URLSession for API calls)

/// Uses WKWebView to solve Cloudflare's managed challenge, then makes API calls
/// via URLSession with the Cloudflare cookies (cf_clearance) + session key.
/// This hybrid approach avoids WKWebView's unreliable cookie handling on macOS 14+.
@MainActor
class ClaudeAPIClient: NSObject {
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"

    private var webView: WKWebView?
    private var hiddenWindow: NSWindow?
    private var webViewReady = false
    // Continuation is matched to its WKNavigation token so stale delegate
    // callbacks from a prior load can't resume the wrong continuation.
    private var pendingNavigation: (token: WKNavigation, cont: CheckedContinuation<Void, Error>)?
    // The org ID that actually returns 200 on /usage — different from
    // memberships[0] for users in multiple orgs.
    private var cachedOrgId: String?
    // Candidate org IDs from bootstrap, ordered by role-based priority.
    // We iterate through these until one returns 200 on /usage.
    private var candidateOrgIds: [String] = []
    private var currentSessionKey: String?

    // Ephemeral URLSession — isolated from `URLSession.shared`'s
    // HTTPCookieStorage which would otherwise persist claude.ai cookies to
    // disk (~/Library/HTTPStorages/<bundle-id>.binarycookies) across app
    // launches and between identities. We set the Cookie header manually,
    // so URLSession must not handle cookies on our behalf.
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }()

    func resetReadyState() {
        webView?.stopLoading()
        if let pending = pendingNavigation {
            pendingNavigation = nil
            pending.cont.resume(throwing: APIError.invalidResponse)
        }
        webViewReady = false
        cachedOrgId = nil
        candidateOrgIds = []
        currentSessionKey = nil
    }

    /// Fully wipe claude.ai cookies and WebKit storage for the domain. Call
    /// when the user switches to a different session/identity so no residual
    /// cf_clearance / lastActiveOrg / auth cookies from the prior account
    /// leak into the new one.
    func purgeClaudeAIState() async {
        guard let wv = webView else { return }
        let store = wv.configuration.websiteDataStore

        // Delete every cookie on claude.ai domains.
        let all = await store.httpCookieStore.allCookies()
        for cookie in all where cookie.domain.contains("claude.ai") {
            await store.httpCookieStore.deleteCookie(cookie)
        }

        // Remove disk-backed data (local storage, cache, etc.) for the claude
        // .ai domain so nothing persists across identity changes.
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        let claudeRecords = records.filter { $0.displayName.contains("claude.ai") }
        if !claudeRecords.isEmpty {
            await store.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                for: claudeRecords
            )
        }

        webViewReady = false
        cachedOrgId = nil
        candidateOrgIds = []
        currentSessionKey = nil
    }

    // MARK: - Main Entry

    func fetchUsage() async throws -> UsageInfo {
        guard let sessionKey = KeychainHelper.load(), !sessionKey.isEmpty else {
            throw APIError.noSessionKey
        }

        // Session key changed? Everything cached is for the previous identity.
        if sessionKey != currentSessionKey {
            cachedOrgId = nil
            candidateOrgIds = []
        }

        ensureWebView()
        try await injectSessionCookie(sessionKey)

        // Up to 2 attempts: if Cloudflare expires mid-session, re-solve once
        for attempt in 1...2 {
            if !webViewReady {
                try await passCloudflare()
                webViewReady = true
            }

            do {
                let cookies = await gatherCookies(sessionKey: sessionKey)

                // Populate the candidate list on first fetch for this identity.
                if candidateOrgIds.isEmpty {
                    candidateOrgIds = try await fetchOrgIdsDirect(cookies: cookies)
                }

                return try await fetchUsageTryingAllOrgs(cookies: cookies)
            } catch APIError.cloudflareBlocked where attempt < 2 {
                logger.info("Cloudflare detected in API response, re-solving...")
                webViewReady = false
                continue
            } catch {
                if case APIError.httpError(let code, _) = error, code == 401 || code == 403 {
                    resetReadyState()
                }
                throw error
            }
        }

        throw APIError.cloudflareBlocked
    }

    /// Try the cached-winning org first, then iterate through all candidates.
    /// Only permission-denied responses trigger the fallback — any other
    /// error (network, Cloudflare, parse) propagates immediately.
    private func fetchUsageTryingAllOrgs(cookies: [HTTPCookie]) async throws -> UsageInfo {
        // Try the cached winning org first.
        if let winner = cachedOrgId {
            do {
                return try await fetchUsageDataDirect(orgId: winner, cookies: cookies)
            } catch APIError.httpError(let code, let detail)
                where (code == 403 || code == 404) && detail.contains("permission") {
                // This org lost its permission (role change, or cache from
                // previous identity). Fall through to re-iterate candidates.
                logger.info("Cached org lost permission — re-scanning candidates.")
                cachedOrgId = nil
            }
        }

        // Iterate candidates in priority order. Remember the last
        // permission error so we can surface it if ALL candidates fail.
        var lastPermissionError: Error?
        for orgId in candidateOrgIds where orgId != cachedOrgId {
            do {
                let info = try await fetchUsageDataDirect(orgId: orgId, cookies: cookies)
                // Winner — cache for subsequent polls.
                cachedOrgId = orgId
                logger.info("Usage endpoint accepted org \(orgId.prefix(8), privacy: .public)…")
                return info
            } catch APIError.httpError(let code, let detail)
                where (code == 403 || code == 404) && detail.contains("permission") {
                logger.info("Org \(orgId.prefix(8), privacy: .public)… denied /usage — trying next.")
                lastPermissionError = APIError.httpError(code, detail)
                continue
            }
            // Any other error exits the loop immediately.
        }

        // All candidates refused.
        if let err = lastPermissionError {
            throw err
        }
        throw APIError.parseError("No organization in this account has permission to read usage.")
    }

    // MARK: - Direct URLSession API Calls

    /// Gather Cloudflare cookies from WebView, always replacing sessionKey with the current one
    private func gatherCookies(sessionKey: String) async -> [HTTPCookie] {
        guard let wv = webView else { return [] }

        // Remove any stale sessionKey cookies from the store
        let allCookies = await wv.configuration.websiteDataStore.httpCookieStore.allCookies()
        for cookie in allCookies where cookie.name == "sessionKey" {
            await wv.configuration.websiteDataStore.httpCookieStore.deleteCookie(cookie)
        }

        // Re-inject the current session key
        if let freshCookie = HTTPCookie(properties: [
            .name: "sessionKey",
            .value: sessionKey,
            .domain: ".claude.ai",
            .path: "/",
            .secure: "TRUE",
            .expires: Date(timeIntervalSinceNow: 86400 * 30)
        ]) {
            await wv.configuration.websiteDataStore.httpCookieStore.setCookie(freshCookie)
        }

        return await wv.configuration.websiteDataStore.httpCookieStore.allCookies()
            .filter { $0.domain.contains("claude.ai") }
    }

    private func directRequest(url: URL, cookies: [HTTPCookie]) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        return request
    }

    /// Fetch ALL organization IDs the session has access to. Many accounts
    /// have multiple memberships (personal + a shared/team org), and only
    /// SOME of those have permission to view `/usage`. Caller iterates
    /// through this list until one returns 200.
    private func fetchOrgIdsDirect(cookies: [HTTPCookie]) async throws -> [String] {
        let url = URL(string: "https://claude.ai/api/bootstrap")!
        let request = directRequest(url: url, cookies: cookies)

        let (data, response) = try await urlSession.data(for: request)
        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""

        if Self.looksLikeCloudflareChallenge(response: http, body: text) {
            throw APIError.cloudflareBlocked
        }

        guard statusCode == 200 else {
            if statusCode == 401 || statusCode == 403 {
                throw APIError.parseError("Session key expired — get a fresh one from claude.ai")
            }
            throw APIError.httpError(statusCode, "Bootstrap failed")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError("Invalid bootstrap response")
        }

        // Check if session is authenticated
        guard let account = json["account"] as? [String: Any] else {
            throw APIError.parseError("Session key expired — get a fresh one from claude.ai")
        }

        let memberships = account["memberships"] as? [[String: Any]] ?? []

        // Prefer orgs where the member has admin/owner/primary-owner role
        // (those typically have usage-read permission). Fall back to all
        // memberships, then to the flat `organization_uuid` if present.
        let prioritized: [[String: Any]] = memberships.sorted { a, b in
            priority(of: a) < priority(of: b)
        }
        var ids: [String] = prioritized.compactMap {
            ($0["organization"] as? [String: Any])?["uuid"] as? String
        }
        if ids.isEmpty, let single = json["organization_uuid"] as? String, !single.isEmpty {
            ids = [single]
        }

        guard !ids.isEmpty else {
            throw APIError.parseError("No organization found — check session key")
        }

        logger.info("Found \(ids.count) organization(s) to try.")
        return ids
    }

    /// Role priority: lower = try first. Primary owner / admin orgs are more
    /// likely to have usage-read permission than orgs the user was merely
    /// invited into as a regular member.
    private func priority(of membership: [String: Any]) -> Int {
        let role = (membership["organization_role"] as? String
            ?? membership["role"] as? String
            ?? "").lowercased()
        switch role {
        case "primary_owner", "owner": return 0
        case "admin": return 1
        case "member": return 2
        default: return 3
        }
    }

    private func fetchUsageDataDirect(orgId: String, cookies: [HTTPCookie]) async throws -> UsageInfo {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
        let request = directRequest(url: url, cookies: cookies)

        let (data, response) = try await urlSession.data(for: request)
        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""

        if Self.looksLikeCloudflareChallenge(response: http, body: text) {
            throw APIError.cloudflareBlocked
        }

        guard statusCode == 200 else {
            // Log the server's response body so we can see WHY /usage was
            // rejected (account tier? scope? missing header?). The /usage
            // endpoint typically returns small JSON error bodies.
            let snippet = String(text.prefix(400))
            logger.error("Usage API non-200 (status=\(statusCode, privacy: .public)): \(snippet, privacy: .public)")
            throw APIError.httpError(statusCode, "Usage API: \(text.prefix(200))")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError("Failed to parse usage JSON")
        }

        #if DEBUG
        // Release builds must not leak the full JSON payload to /tmp.
        if let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyStr = String(data: prettyData, encoding: .utf8) {
            try? prettyStr.write(toFile: "/tmp/claudemeter_usage_response.json", atomically: true, encoding: .utf8)
            logger.debug("Usage response dumped to /tmp/claudemeter_usage_response.json")
        }
        #endif
        logger.info("Usage response keys: \(Array(json.keys).sorted())")

        guard let info = parseUsage(json) else {
            throw APIError.parseError("Unexpected usage response format — keys: \(Array(json.keys))")
        }

        logger.info("Usage: session=\(info.usagePercentInt)% daily=\(info.daily?.percentInt ?? -1)% weekly=\(info.weekly?.percentInt ?? -1)%")
        return info
    }

    // MARK: - WebView Setup (Cloudflare only)

    private func ensureWebView() {
        guard webView == nil else { return }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        wv.navigationDelegate = self
        wv.customUserAgent = userAgent

        // Window starts hidden — shown only during Cloudflare solving.
        // macOS 14+ throttles JS in off-screen/hidden windows, preventing
        // Cloudflare's managed challenge from completing.
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        win.title = "ClaudeMeter Pro — Connecting"
        win.contentView = wv
        win.isReleasedWhenClosed = false

        self.webView = wv
        self.hiddenWindow = win
    }

    private func injectSessionCookie(_ sessionKey: String) async throws {
        guard let wv = webView else { return }
        currentSessionKey = sessionKey

        let cookie = HTTPCookie(properties: [
            .name: "sessionKey",
            .value: sessionKey,
            .domain: ".claude.ai",
            .path: "/",
            .secure: "TRUE",
            .expires: Date(timeIntervalSinceNow: 86400 * 30)
        ])
        if let cookie {
            await wv.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }
    }

    // MARK: - Cloudflare Challenge

    private func passCloudflare() async throws {
        logger.info("Loading claude.ai to solve Cloudflare challenge...")

        // Show WebView window so macOS doesn't throttle JS execution
        showWebViewWindow()

        try await navigateTo("https://claude.ai/")

        for attempt in 1...20 {
            try await Task.sleep(nanoseconds: 1_500_000_000)

            let title = (try? await callJS("return document.title")) as? String ?? ""

            if !title.isEmpty && !title.contains("Just a moment") {
                logger.info("Cloudflare solved after \(attempt) checks")
                try await Task.sleep(nanoseconds: 500_000_000)
                hideWebViewWindow()
                return
            }

            if attempt % 5 == 0 {
                let status = (try? await callJS("""
                    try {
                        const r = await fetch('/api/bootstrap', { credentials: 'include' });
                        return String(r.status);
                    } catch(e) { return 'error'; }
                """)) as? String ?? "error"

                if status == "200" {
                    logger.info("API reachable despite challenge title")
                    hideWebViewWindow()
                    return
                }
            }
        }

        hideWebViewWindow()
        throw APIError.cloudflareBlocked
    }

    private func showWebViewWindow() {
        guard let win = hiddenWindow else { return }
        win.center()
        // Show without stealing focus from the user's current app. macOS 14+
        // throttles JS in fully hidden windows, so we need it on-screen, but
        // we don't need it frontmost.
        win.orderFrontRegardless()
    }

    private func hideWebViewWindow() {
        hiddenWindow?.orderOut(nil)
    }

    /// Detect Cloudflare challenges in a locale-agnostic way. Claude.ai
    /// localizes the challenge HTML, so English-only text matches miss.
    static func looksLikeCloudflareChallenge(response: HTTPURLResponse?, body: String) -> Bool {
        if let cfMitigated = response?.value(forHTTPHeaderField: "cf-mitigated"),
           !cfMitigated.isEmpty {
            return true
        }
        if let contentType = response?.value(forHTTPHeaderField: "Content-Type"),
           contentType.localizedCaseInsensitiveContains("text/html") {
            // /api/bootstrap and /api/organizations/.../usage always return
            // JSON on success — HTML back means a challenge/interstitial.
            return true
        }
        // Defensive text markers for the challenge page body.
        if body.contains("Just a moment")
            || body.contains("cf-challenge")
            || body.contains("challenge-platform")
            || body.contains("_cf_chl_opt") {
            return true
        }
        return false
    }

    // MARK: - Parse Usage

    private func parseTier(_ dict: [String: Any]) -> UsageTier? {
        guard let utilization = dict["utilization"] as? Double else { return nil }
        return UsageTier(
            percent: utilization / 100.0,
            resetDate: parseISO8601(dict["resets_at"] as? String)
        )
    }

    private func parseUsage(_ dict: [String: Any]) -> UsageInfo? {
        // Parse known tiers from the API response
        let fiveHourTier = (dict["five_hour"] as? [String: Any]).flatMap { parseTier($0) }
        let sevenDayTier = (dict["seven_day"] as? [String: Any]).flatMap { parseTier($0) }
        let dailyTier = (dict["daily"] as? [String: Any]).flatMap { parseTier($0) }

        // Primary: five_hour session > root-level > daily
        if let session = fiveHourTier {
            return UsageInfo(
                sessionPercent: session.percent,
                sessionResetDate: session.resetDate,
                daily: dailyTier,
                weekly: sevenDayTier
            )
        }

        // Root-level utilization (flat response format)
        if let utilization = dict["utilization"] as? Double {
            return UsageInfo(
                sessionPercent: utilization / 100.0,
                sessionResetDate: parseISO8601(dict["resets_at"] as? String),
                daily: dailyTier,
                weekly: sevenDayTier
            )
        }

        // Fall back to daily as primary
        if let daily = dailyTier {
            return UsageInfo(
                sessionPercent: daily.percent,
                sessionResetDate: daily.resetDate,
                daily: daily,
                weekly: sevenDayTier
            )
        }

        return nil
    }

    // Cached formatters — ISO8601DateFormatter allocation is not cheap and
    // parseISO8601 runs on every poll for every tier.
    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string else { return nil }
        if let date = Self.isoWithFractional.date(from: string) { return date }
        return Self.isoPlain.date(from: string)
    }

    // MARK: - WebView Helpers

    private func navigateTo(_ urlString: String) async throws {
        guard let wv = webView, let url = URL(string: urlString) else {
            throw APIError.invalidResponse
        }

        // Cancel any in-flight navigation deterministically before starting a new one.
        let prior = pendingNavigation
        pendingNavigation = nil
        wv.stopLoading()
        prior?.cont.resume(throwing: APIError.invalidResponse)

        return try await withCheckedThrowingContinuation { continuation in
            // Register continuation against the new navigation's token so
            // late delegate callbacks from the prior load are discarded.
            if let token = wv.load(URLRequest(url: url)) {
                self.pendingNavigation = (token, continuation)
            } else {
                continuation.resume(throwing: APIError.invalidResponse)
            }
        }
    }

    private func callJS(_ script: String) async throws -> Any? {
        guard let wv = webView else { throw APIError.invalidResponse }
        return try await wv.callAsyncJavaScript(
            script,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
    }
}

// MARK: - WKNavigationDelegate

extension ClaudeAPIClient: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard let pending = pendingNavigation, pending.token === navigation else { return }
            pendingNavigation = nil
            pending.cont.resume()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard let pending = pendingNavigation, pending.token === navigation else { return }
            pendingNavigation = nil
            pending.cont.resume(throwing: APIError.networkError(error))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard let pending = pendingNavigation, pending.token === navigation else { return }
            pendingNavigation = nil
            pending.cont.resume(throwing: APIError.networkError(error))
        }
    }
}
