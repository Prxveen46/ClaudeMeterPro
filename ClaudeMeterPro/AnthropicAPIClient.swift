import Foundation
import WebKit
import os.log

private let logger = Logger(subsystem: "com.claudemeterpro", category: "APIClient")

// MARK: - Models

struct UsageInfo {
    let sessionPercent: Double       // 0.0 - 1.0
    let sessionResetDate: Date?      // absolute reset time

    var sessionPercentInt: Int { min(100, Int(sessionPercent * 100)) }
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
        case .cloudflareBlocked: return "Cloudflare blocked — open claude.ai in Safari first, then retry"
        case .httpError(let code, let detail): return "HTTP \(code): \(detail)"
        case .parseError(let msg): return msg
        case .networkError(let err): return err.localizedDescription
        }
    }
}

// MARK: - Direct URLSession Client (primary, fast path)

@MainActor
class ClaudeAPIClient: NSObject {
    private let session: URLSession
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"

    // WebView fallback for Cloudflare challenges
    private var webView: WKWebView?
    private var hiddenWindow: NSWindow?
    private var webViewReady = false
    private var navigationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        self.session = URLSession(configuration: config)
        super.init()
    }

    func resetReadyState() {
        webView?.stopLoading()
        if let cont = navigationContinuation {
            navigationContinuation = nil
            cont.resume(throwing: APIError.invalidResponse)
        }
        webViewReady = false
    }

    // MARK: - Main Entry

    func fetchUsage() async throws -> UsageInfo {
        guard let sessionKey = KeychainHelper.load(), !sessionKey.isEmpty else {
            throw APIError.noSessionKey
        }

        // Try direct URLSession first (fast, no WebView overhead)
        do {
            return try await fetchUsageDirect(sessionKey: sessionKey)
        } catch let error as APIError {
            logger.info("Direct fetch failed: \(error.localizedDescription)")
            switch error {
            case .cloudflareBlocked:
                logger.info("Falling back to WebView")
                return try await fetchUsageViaWebView(sessionKey: sessionKey)
            default:
                throw error
            }
        }
    }

    // MARK: - Direct URLSession Approach

    private func fetchUsageDirect(sessionKey: String) async throws -> UsageInfo {
        // Step 1: Bootstrap to get org ID
        let orgId = try await fetchOrgIdDirect(sessionKey: sessionKey)

        // Step 2: Fetch usage
        return try await fetchUsageDataDirect(sessionKey: sessionKey, orgId: orgId)
    }

    private func makeRequest(url: URL, sessionKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://claude.ai/", forHTTPHeaderField: "Referer")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        return request
    }

    private func isCloudflareChallenge(_ response: HTTPURLResponse, data: Data) -> Bool {
        let status = response.statusCode
        if status == 403 || status == 503 {
            let body = String(data: data, encoding: .utf8) ?? ""
            return body.contains("Just a moment") || body.contains("cf-browser-verification")
                || body.contains("challenge-platform") || body.contains("cloudflare")
        }
        return false
    }

    private func fetchOrgIdDirect(sessionKey: String) async throws -> String {
        guard let url = URL(string: "https://claude.ai/api/bootstrap") else {
            throw APIError.invalidResponse
        }

        let request = makeRequest(url: url, sessionKey: sessionKey)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if isCloudflareChallenge(httpResponse, data: data) {
            throw APIError.cloudflareBlocked
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode, "Bootstrap failed")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError("Invalid bootstrap response")
        }

        // Try multiple paths for org ID — API format varies
        let orgId: String? = {
            // Path 1: account.memberships[0].organization.uuid
            if let account = json["account"] as? [String: Any],
               let memberships = account["memberships"] as? [[String: Any]],
               let first = memberships.first,
               let org = first["organization"] as? [String: Any],
               let uuid = org["uuid"] as? String, !uuid.isEmpty {
                return uuid
            }
            // Path 2: Top-level organization_uuid (some API versions)
            if let uuid = json["organization_uuid"] as? String, !uuid.isEmpty {
                return uuid
            }
            // Path 3: Direct uuid field on account
            if let account = json["account"] as? [String: Any],
               let memberships = account["memberships"] as? [[String: Any]],
               let first = memberships.first,
               let uuid = first["organization_uuid"] as? String, !uuid.isEmpty {
                return uuid
            }
            return nil
        }()

        guard let orgId, !orgId.isEmpty else {
            throw APIError.parseError("No organization ID found — check your session key")
        }
        return orgId
    }

    private func fetchUsageDataDirect(sessionKey: String, orgId: String) async throws -> UsageInfo {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else {
            throw APIError.invalidResponse
        }

        let request = makeRequest(url: url, sessionKey: sessionKey)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if isCloudflareChallenge(httpResponse, data: data) {
            throw APIError.cloudflareBlocked
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode, "Usage API failed")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError("Failed to parse usage JSON")
        }

        guard let info = parseUsage(json) else {
            throw APIError.parseError("Unexpected usage response format")
        }
        return info
    }

    // MARK: - WebView Fallback (for Cloudflare challenges)

    private func fetchUsageViaWebView(sessionKey: String) async throws -> UsageInfo {
        ensureWebView()

        // Inject session key cookie
        guard let cookie = HTTPCookie(properties: [
            .name: "sessionKey",
            .value: sessionKey,
            .domain: ".claude.ai",
            .path: "/",
            .secure: true
        ]) else {
            throw APIError.parseError("Invalid session key format")
        }
        await webView!.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)

        if !webViewReady {
            try await passCloudflare()
            webViewReady = true
        }

        let orgId = try await fetchOrgIdViaWebView()
        return try await fetchUsageDataViaWebView(orgId: orgId)
    }

    private func ensureWebView() {
        guard webView == nil else { return }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), configuration: config)
        wv.navigationDelegate = self
        wv.customUserAgent = userAgent

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        win.contentView = wv
        win.orderOut(nil)

        self.webView = wv
        self.hiddenWindow = win
    }

    private func passCloudflare() async throws {
        logger.info("Navigating to claude.ai for Cloudflare challenge...")
        try await navigateTo("https://claude.ai/")

        for attempt in 1...10 {
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let title = (try? await callJS("return document.title")) as? String ?? ""
            logger.info("Cloudflare check \(attempt)/10 — title: \(title)")

            if !title.isEmpty && !title.contains("Just a moment") {
                logger.info("Cloudflare bypass complete")
                return
            }
        }

        let canReach = (try? await callJS("""
            try {
                const r = await fetch('/api/bootstrap', { credentials: 'include' });
                return String(r.status);
            } catch(e) { return 'error'; }
        """)) as? String ?? "error"

        if canReach == "200" {
            logger.info("Cloudflare bypass succeeded (API reachable despite title)")
            return
        }

        throw APIError.cloudflareBlocked
    }

    private func fetchOrgIdViaWebView() async throws -> String {
        let js = """
        const resp = await fetch('/api/bootstrap', {
            credentials: 'include',
            headers: { 'Accept': 'application/json' }
        });
        if (!resp.ok) return JSON.stringify({ error: 'HTTP ' + resp.status });
        const data = await resp.json();
        const memberships = data.account?.memberships || [];
        const orgId = memberships[0]?.organization?.uuid || data.organization_uuid || '';
        return JSON.stringify({ orgId: orgId });
        """

        let result: String
        do {
            result = try await callJS(js) as? String ?? "{}"
        } catch {
            resetReadyState()
            throw APIError.parseError("Bootstrap failed: \(error.localizedDescription)")
        }

        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            resetReadyState()
            throw APIError.parseError("Invalid bootstrap response")
        }

        if let apiError = json["error"] as? String {
            resetReadyState()
            throw APIError.httpError(0, "Bootstrap: \(apiError)")
        }

        guard let orgId = json["orgId"] as? String, !orgId.isEmpty else {
            resetReadyState()
            throw APIError.parseError("No organization ID found — check your session key")
        }

        logger.info("Org ID (WebView): \(orgId.prefix(8))...")
        return orgId
    }

    private func fetchUsageDataViaWebView(orgId: String) async throws -> UsageInfo {
        let js = """
        const resp = await fetch('/api/organizations/\(orgId)/usage', {
            credentials: 'include',
            headers: { 'Accept': 'application/json' }
        });
        if (!resp.ok) return JSON.stringify({ error: 'HTTP ' + resp.status });
        return await resp.text();
        """

        let result: String
        do {
            result = try await callJS(js) as? String ?? "{}"
        } catch {
            throw APIError.parseError("Usage fetch failed: \(error.localizedDescription)")
        }

        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError("Failed to parse usage JSON")
        }

        if let apiError = json["error"] as? String {
            throw APIError.httpError(0, "Usage API: \(apiError)")
        }

        guard let info = parseUsage(json) else {
            logger.error("Unexpected usage format: \(result.prefix(300))")
            throw APIError.parseError("Unexpected usage response format")
        }

        logger.info("Usage fetch complete (WebView): \(info.sessionPercentInt)%")
        return info
    }

    // MARK: - Parse Usage

    private func parseUsage(_ dict: [String: Any]) -> UsageInfo? {
        // API returns: { "five_hour": { "utilization": 17.0, "resets_at": "ISO8601" }, ... }
        guard let fiveHour = dict["five_hour"] as? [String: Any],
              let utilization = fiveHour["utilization"] as? Double else {
            return nil
        }

        var resetDate: Date?
        if let resetsAt = fiveHour["resets_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            resetDate = formatter.date(from: resetsAt)
            if resetDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                resetDate = formatter.date(from: resetsAt)
            }
        }

        return UsageInfo(
            sessionPercent: utilization / 100.0,
            sessionResetDate: resetDate
        )
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
