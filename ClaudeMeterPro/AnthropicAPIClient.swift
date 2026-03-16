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
    case parseError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noSessionKey: return "No session key configured"
        case .invalidResponse: return "Invalid response"
        case .cloudflareBlocked: return "Cloudflare challenge failed — try opening claude.ai in Safari first"
        case .parseError(let msg): return msg
        case .networkError(let err): return err.localizedDescription
        }
    }
}

// MARK: - Web-based API Client

@MainActor
class ClaudeWebClient: NSObject {
    private var webView: WKWebView!
    private var hiddenWindow: NSWindow!
    private var isReady = false
    private var navigationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        setupWebView()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 300), configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        hiddenWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        hiddenWindow.contentView = webView
        hiddenWindow.orderOut(nil)
    }

    func teardown() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        hiddenWindow.contentView = nil
    }

    func resetReadyState() {
        webView.stopLoading()
        // Safely discard any pending continuation
        if let cont = navigationContinuation {
            navigationContinuation = nil
            cont.resume(throwing: APIError.invalidResponse)
        }
        isReady = false
    }

    func fetchUsage() async throws -> UsageInfo {
        guard let sessionKey = KeychainHelper.load() else {
            throw APIError.noSessionKey
        }

        // Set session key cookie
        guard let cookie = HTTPCookie(properties: [
            .name: "sessionKey",
            .value: sessionKey,
            .domain: ".claude.ai",
            .path: "/",
            .secure: true
        ]) else {
            throw APIError.parseError("Invalid session key format")
        }
        await webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)

        // Step 1: Navigate to claude.ai to pass Cloudflare (first time only)
        if !isReady {
            logger.info("Navigating to claude.ai for Cloudflare bypass")
            try await navigateTo("https://claude.ai/")
            try await Task.sleep(nanoseconds: 4_000_000_000)

            let title: String
            do {
                title = try await callJS("return document.title") as? String ?? ""
            } catch {
                title = ""
            }

            if title.contains("Just a moment") || title.isEmpty {
                try await Task.sleep(nanoseconds: 6_000_000_000)
                let title2 = (try? await callJS("return document.title") as? String) ?? ""
                if title2.contains("Just a moment") || title2.isEmpty {
                    throw APIError.cloudflareBlocked
                }
            }
            isReady = true
            logger.info("Cloudflare bypass complete")
        }

        // Step 2: Get org ID
        let bootstrapJS = """
        const resp = await fetch('/api/bootstrap', {
            credentials: 'include',
            headers: { 'Accept': 'application/json' }
        });
        if (!resp.ok) return JSON.stringify({ error: 'HTTP ' + resp.status });
        const data = await resp.json();
        const memberships = data.account?.memberships || [];
        const orgId = memberships[0]?.organization?.uuid || '';
        return JSON.stringify({ orgId: orgId });
        """

        let bootstrapResult: String
        do {
            bootstrapResult = try await callJS(bootstrapJS) as? String ?? "{}"
        } catch {
            resetReadyState()
            throw APIError.parseError("Bootstrap failed: \(error.localizedDescription)")
        }

        guard let bootstrapData = bootstrapResult.data(using: .utf8),
              let bootstrapJson = try? JSONSerialization.jsonObject(with: bootstrapData) as? [String: Any],
              let orgId = bootstrapJson["orgId"] as? String, !orgId.isEmpty else {
            resetReadyState()
            throw APIError.parseError("Could not get organization ID")
        }

        logger.info("Bootstrap complete")

        // Step 3: Fetch usage
        let usageJS = """
        const resp = await fetch('/api/organizations/\(orgId)/usage', {
            credentials: 'include',
            headers: { 'Accept': 'application/json' }
        });
        if (!resp.ok) return JSON.stringify({ error: 'HTTP ' + resp.status });
        const text = await resp.text();
        return text;
        """

        let usageResult: String
        do {
            usageResult = try await callJS(usageJS) as? String ?? "{}"
        } catch {
            throw APIError.parseError("Usage fetch failed: \(error.localizedDescription)")
        }

        guard let usageData = usageResult.data(using: .utf8),
              let usageJson = try? JSONSerialization.jsonObject(with: usageData) as? [String: Any] else {
            throw APIError.parseError("Failed to parse usage JSON")
        }

        guard let info = parseUsage(usageJson) else {
            throw APIError.parseError("Unexpected API response format")
        }

        logger.info("Usage fetch complete")
        return info
    }

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

    // MARK: - Helpers

    private func navigateTo(_ urlString: String) async throws {
        guard let url = URL(string: urlString) else { throw APIError.invalidResponse }

        // Cancel any in-flight navigation
        webView.stopLoading()
        if let cont = navigationContinuation {
            navigationContinuation = nil
            cont.resume(throwing: APIError.invalidResponse)
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.navigationContinuation = continuation
            webView.load(URLRequest(url: url))
        }
    }

    private func callJS(_ script: String) async throws -> Any? {
        return try await webView.callAsyncJavaScript(
            script,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
    }
}

// MARK: - WKNavigationDelegate

extension ClaudeWebClient: WKNavigationDelegate {
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
