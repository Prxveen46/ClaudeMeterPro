import Foundation
import WebKit
import os.log

private let logger = Logger(subsystem: "com.claudemeterpro", category: "APIClient")

// MARK: - Models

struct UsageInfo {
    let sessionPercent: Double       // 0.0 - 1.0
    let sessionResetDate: Date?      // absolute reset time

    var usagePercentInt: Int { min(100, Int(sessionPercent * 100)) }
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

// MARK: - WebView-based Client

/// Uses WKWebView to bypass Cloudflare, then runs fetch() inside the WebView context.
/// The WebView must be in a real (off-screen) window with a proper style mask so macOS
/// doesn't throttle JavaScript execution.
@MainActor
class ClaudeAPIClient: NSObject {
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"

    private var webView: WKWebView?
    private var hiddenWindow: NSWindow?
    private var webViewReady = false
    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var cachedOrgId: String?

    func resetReadyState() {
        webView?.stopLoading()
        if let cont = navigationContinuation {
            navigationContinuation = nil
            cont.resume(throwing: APIError.invalidResponse)
        }
        webViewReady = false
        cachedOrgId = nil
    }

    // MARK: - Main Entry

    func fetchUsage() async throws -> UsageInfo {
        guard let sessionKey = KeychainHelper.load(), !sessionKey.isEmpty else {
            throw APIError.noSessionKey
        }

        ensureWebView()
        try await injectSessionCookie(sessionKey)

        // Up to 2 attempts: if Cloudflare expires mid-session, re-solve once
        for attempt in 1...2 {
            // Pass Cloudflare on first call (or after reset / expiry)
            if !webViewReady {
                try await passCloudflare()
                webViewReady = true
            }

            // Get org ID (cached after first success)
            if cachedOrgId == nil {
                do {
                    cachedOrgId = try await fetchOrgId()
                } catch APIError.cloudflareBlocked where attempt < 2 {
                    logger.info("Cloudflare expired during org fetch, re-solving...")
                    webViewReady = false
                    continue
                }
            }

            do {
                return try await fetchUsageData(orgId: cachedOrgId!)
            } catch APIError.cloudflareBlocked where attempt < 2 {
                logger.info("Cloudflare expired during usage fetch, re-solving...")
                webViewReady = false
                continue
            } catch {
                // On auth errors, clear everything so next poll starts fresh
                if case APIError.httpError(let code, _) = error, code == 401 || code == 403 {
                    resetReadyState()
                }
                throw error
            }
        }

        throw APIError.cloudflareBlocked
    }

    // MARK: - WebView Setup

    private func ensureWebView() {
        guard webView == nil else { return }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        // Ensure JS is fully enabled
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        wv.navigationDelegate = self
        wv.customUserAgent = userAgent

        // CRITICAL: Use a real titled window placed off-screen.
        // A styleMask:[] + orderOut window causes macOS to throttle/suspend JS,
        // which prevents Cloudflare's managed challenge from solving.
        let win = NSWindow(
            contentRect: NSRect(x: -20000, y: -20000, width: 800, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        win.contentView = wv
        win.isReleasedWhenClosed = false
        // orderBack keeps it behind everything, off-screen position makes it invisible
        win.orderBack(nil)

        self.webView = wv
        self.hiddenWindow = win
    }

    private func injectSessionCookie(_ sessionKey: String) async throws {
        guard let wv = webView else { return }

        let cookie = HTTPCookie(properties: [
            .name: "sessionKey",
            .value: sessionKey,
            .domain: ".claude.ai",
            .path: "/",
            .secure: true
        ])
        guard let cookie else {
            throw APIError.parseError("Invalid session key format")
        }
        await wv.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
    }

    // MARK: - Cloudflare Challenge

    private func passCloudflare() async throws {
        logger.info("Loading claude.ai to solve Cloudflare challenge...")

        // Navigate to the main page so Cloudflare can run its managed challenge
        try await navigateTo("https://claude.ai/")

        // Poll until the Cloudflare challenge resolves.
        // Managed challenges typically resolve in 3-8 seconds.
        for attempt in 1...20 {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s per check

            // Check page title — Cloudflare challenge page has "Just a moment..."
            let title = (try? await callJS("return document.title")) as? String ?? ""

            if !title.isEmpty && !title.contains("Just a moment") {
                logger.info("Cloudflare solved after \(attempt) checks")
                // Small extra wait for cookies to propagate
                try await Task.sleep(nanoseconds: 500_000_000)
                return
            }

            // Every 5 attempts, check if the API is actually reachable despite title
            if attempt % 5 == 0 {
                let status = (try? await callJS("""
                    try {
                        const r = await fetch('/api/bootstrap', { credentials: 'include' });
                        return String(r.status);
                    } catch(e) { return 'error'; }
                """)) as? String ?? "error"

                if status == "200" {
                    logger.info("API reachable (title still shows challenge, but fetch works)")
                    return
                }
                logger.info("Cloudflare check \(attempt)/20 — title: \(title), api status: \(status)")
            }
        }

        throw APIError.cloudflareBlocked
    }

    // MARK: - Fetch Org ID

    private func fetchOrgId() async throws -> String {
        let js = """
        try {
            const resp = await fetch('/api/bootstrap', {
                credentials: 'include',
                headers: { 'Accept': 'application/json' }
            });
            const text = await resp.text();
            if (text.includes('Just a moment') || text.includes('cf-challenge') || text.includes('_cf_chl') || text.includes('challenge-platform')) {
                return JSON.stringify({ cloudflare: true });
            }
            if (!resp.ok) return JSON.stringify({ error: resp.status });
            const data = JSON.parse(text);
            const m = data.account?.memberships || [];
            const orgId = m[0]?.organization?.uuid
                       || data.organization_uuid
                       || m[0]?.organization_uuid
                       || '';
            return JSON.stringify({ orgId: orgId });
        } catch(e) {
            return JSON.stringify({ error: e.message });
        }
        """

        let result = try await callJS(js) as? String ?? "{}"

        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            resetReadyState()
            throw APIError.parseError("Invalid bootstrap response")
        }

        if json["cloudflare"] != nil {
            throw APIError.cloudflareBlocked
        }

        if let errorVal = json["error"] {
            let errorStr = "\(errorVal)"
            if errorStr.contains("401") || errorStr.contains("403") {
                resetReadyState()
                throw APIError.parseError("Session key expired — get a fresh one from claude.ai")
            }
            throw APIError.httpError(0, "Bootstrap: \(errorStr)")
        }

        guard let orgId = json["orgId"] as? String, !orgId.isEmpty else {
            resetReadyState()
            throw APIError.parseError("No organization ID found — check your session key")
        }

        logger.info("Org ID: \(orgId.prefix(8))...")
        return orgId
    }

    // MARK: - Fetch Usage Data

    private func fetchUsageData(orgId: String) async throws -> UsageInfo {
        let js = """
        try {
            const resp = await fetch('/api/organizations/\(orgId)/usage', {
                credentials: 'include',
                headers: { 'Accept': 'application/json' }
            });
            const text = await resp.text();
            if (text.includes('Just a moment') || text.includes('cf-challenge') || text.includes('_cf_chl') || text.includes('challenge-platform')) {
                return JSON.stringify({ cloudflare: true });
            }
            if (!resp.ok) return JSON.stringify({ error: resp.status });
            return text;
        } catch(e) {
            return JSON.stringify({ error: e.message });
        }
        """

        let result = try await callJS(js) as? String ?? "{}"

        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError("Failed to parse usage JSON")
        }

        if json["cloudflare"] != nil {
            throw APIError.cloudflareBlocked
        }

        if let errorVal = json["error"] {
            throw APIError.httpError(0, "Usage API: \(errorVal)")
        }

        guard let info = parseUsage(json) else {
            logger.error("Unexpected usage format: \(result.prefix(500))")
            throw APIError.parseError("Unexpected usage response format")
        }

        logger.info("Usage: \(info.usagePercentInt)%")
        return info
    }

    // MARK: - Parse Usage

    private func parseUsage(_ dict: [String: Any]) -> UsageInfo? {
        // Try the known format: { "five_hour": { "utilization": 17.0, "resets_at": "..." } }
        if let fiveHour = dict["five_hour"] as? [String: Any],
           let utilization = fiveHour["utilization"] as? Double {
            return UsageInfo(
                sessionPercent: utilization / 100.0,
                sessionResetDate: parseISO8601(fiveHour["resets_at"] as? String)
            )
        }

        // Fallback: try top-level "utilization" field
        if let utilization = dict["utilization"] as? Double {
            return UsageInfo(
                sessionPercent: utilization / 100.0,
                sessionResetDate: parseISO8601(dict["resets_at"] as? String)
            )
        }

        // Fallback: try "daily" bucket
        if let daily = dict["daily"] as? [String: Any],
           let utilization = daily["utilization"] as? Double {
            return UsageInfo(
                sessionPercent: utilization / 100.0,
                sessionResetDate: parseISO8601(daily["resets_at"] as? String)
            )
        }

        return nil
    }

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    // MARK: - WebView Helpers

    private func navigateTo(_ urlString: String) async throws {
        guard let wv = webView, let url = URL(string: urlString) else {
            throw APIError.invalidResponse
        }

        wv.stopLoading()
        // Cancel any pending continuation
        if let cont = navigationContinuation {
            navigationContinuation = nil
            cont.resume(throwing: APIError.invalidResponse)
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.navigationContinuation = continuation
            wv.load(URLRequest(url: url))
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
            guard let cont = navigationContinuation else { return }
            navigationContinuation = nil
            cont.resume()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard let cont = navigationContinuation else { return }
            navigationContinuation = nil
            cont.resume(throwing: APIError.networkError(error))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard let cont = navigationContinuation else { return }
            navigationContinuation = nil
            cont.resume(throwing: APIError.networkError(error))
        }
    }
}
