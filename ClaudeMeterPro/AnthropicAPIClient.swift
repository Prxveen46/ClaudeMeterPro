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
    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var cachedOrgId: String?
    private var currentSessionKey: String?

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
            if !webViewReady {
                try await passCloudflare()
                webViewReady = true
            }

            // Use URLSession with Cloudflare cookies from WebView + fresh session key
            do {
                let cookies = await gatherCookies(sessionKey: sessionKey)

                if cachedOrgId == nil {
                    cachedOrgId = try await fetchOrgIdDirect(cookies: cookies)
                }

                return try await fetchUsageDataDirect(orgId: cachedOrgId!, cookies: cookies)
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

    private func fetchOrgIdDirect(cookies: [HTTPCookie]) async throws -> String {
        let url = URL(string: "https://claude.ai/api/bootstrap")!
        let request = directRequest(url: url, cookies: cookies)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""

        if text.contains("Just a moment") || text.contains("cf-challenge") {
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
        let orgId = (memberships.first?["organization"] as? [String: Any])?["uuid"] as? String
            ?? json["organization_uuid"] as? String
            ?? ""

        guard !orgId.isEmpty else {
            throw APIError.parseError("No organization found — check session key")
        }

        logger.info("Org ID: \(orgId.prefix(8))...")
        return orgId
    }

    private func fetchUsageDataDirect(orgId: String, cookies: [HTTPCookie]) async throws -> UsageInfo {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
        let request = directRequest(url: url, cookies: cookies)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""

        if text.contains("Just a moment") || text.contains("cf-challenge") {
            throw APIError.cloudflareBlocked
        }

        guard statusCode == 200 else {
            throw APIError.httpError(statusCode, "Usage API: \(text.prefix(200))")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError("Failed to parse usage JSON")
        }

        guard let info = parseUsage(json) else {
            throw APIError.parseError("Unexpected usage response format")
        }

        logger.info("Usage: \(info.usagePercentInt)%")
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
        win.orderBack(nil)
    }

    private func hideWebViewWindow() {
        hiddenWindow?.orderOut(nil)
    }

    // MARK: - Parse Usage

    private func parseUsage(_ dict: [String: Any]) -> UsageInfo? {
        if let fiveHour = dict["five_hour"] as? [String: Any],
           let utilization = fiveHour["utilization"] as? Double {
            return UsageInfo(
                sessionPercent: utilization / 100.0,
                sessionResetDate: parseISO8601(fiveHour["resets_at"] as? String)
            )
        }

        if let utilization = dict["utilization"] as? Double {
            return UsageInfo(
                sessionPercent: utilization / 100.0,
                sessionResetDate: parseISO8601(dict["resets_at"] as? String)
            )
        }

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
