# QA Fixes — New Session ID Crash + Related Bugs

## Reported symptom
"Whenever I put on a new session ID and try to connect to it, it doesn't connect."

## Root cause
`ClaudeAPIClient` caches `cachedOrgId` across the life of the process. When a user pastes a new session key, the next fetch hits `/api/organizations/{OLD_ORG_ID}/usage` with the new user's cookies → 403/404. The retry logic does eventually reset, but the user sees a 10–20 second error window and the UI never clears stale data.

## Fixes applied (this session)

- [x] **#1** `AnthropicAPIClient.fetchUsage` — compare session key against `currentSessionKey`; on change, drop `cachedOrgId`.
- [x] **#2** `UsageStore.setSessionKey` — clear `usageInfo`, `lastError`, `consecutiveFailures`, `webClient.resetReadyState()`. Wire `SettingsView.validateAndSave` and `OnboardingView.validateKey` through it.
- [x] **#3** `UsageStore.fetchUsage(force:)` — user-initiated fetches bypass the `isLoading` guard (with 5s wait window for in-flight polls).
- [x] **#4** `UsageHistoryStore.bindOptionalDate` — use `SQLITE_TRANSIENT` so SQLite copies the string buffer (fixes silent history corruption / potential crash on recordSnapshot).
- [x] **#5** `AnthropicAPIClient` — continuation is now keyed by `WKNavigation` token; stale delegate callbacks from prior loads are discarded instead of resuming the wrong continuation.
- [x] **#6** `UsageStore.fetchUsage` retry loop — 401/403 now breaks the loop immediately with "Session key rejected — paste a fresh one from claude.ai".
- [x] **Verify** — `swift build -c release` passes cleanly (10.84s).

## Second pass — remaining QA audit items

- [x] **#7** Locale-agnostic Cloudflare detection (headers: `cf-mitigated`, `Content-Type: text/html`, plus extra text markers).
- [x] **#8** `/tmp/claudemeter_usage_response.json` debug dump wrapped in `#if DEBUG`.
- [x] **#9** `UsageStore.init` assigns `_refreshInterval` / `_menuBarStyle` / `_launchAtLogin` through `Published(initialValue:)` — no more didSet cascades during init.
- [x] **#10** `GlobalShortcut` — `RegisterEventHotKey` and `InstallEventHandler` statuses are checked and logged; status-bar lookup is now a non-crashing defensive walk.
- [x] **#12** `launchAtLogin` plist uses `/usr/bin/open -a <bundle-path>` so the LaunchAgent survives the user moving the `.app`.
- [x] **#13** Double-launch shows an NSAlert ("ClaudeMeter Pro is already running — check your menu bar") before exit.
- [x] **#14** Cloudflare-solve window uses `orderFrontRegardless` (visible for JS, no focus theft).
- [x] **#15/17** `ISO8601DateFormatter` instances cached statically in `AnthropicAPIClient` and `UsageHistoryStore`.
- [x] **#18** `landing/.gitignore` content verified (just `.vercel`) — file is correct, just untracked; will commit with the rest.

### Items intentionally not changed

- **#11** Onboarding "Checking..." stuck state — reviewed; `isValidating` always resets to false after the Task completes and the Connect button re-enables, so there's no actual stuck state, just an error message. Nothing to fix.
- **#16** `UsageHistoryStore @unchecked Sendable` — current pattern (all mutation funneled through `queue`) is sound; migrating to an `actor` would be a larger refactor without a user-visible benefit.

## Review

### What changed

**AnthropicAPIClient.swift**
- Added session-key-change detection at the top of `fetchUsage`: when `KeychainHelper.load()` returns a different key than `currentSessionKey`, `cachedOrgId = nil`. This is the direct fix for the reported bug.
- Replaced `navigationContinuation: CheckedContinuation?` with `pendingNavigation: (token: WKNavigation, cont: Continuation)?`. Delegate callbacks compare `pending.token === navigation` before resuming, so stale callbacks from a torn-down prior load can never resume a newly-installed continuation.

**UsageStore.swift**
- `setSessionKey` now owns the identity-change protocol: save key → clear usageInfo/lastError/consecutiveFailures/retryTimer → `webClient.resetReadyState()` → restart polling. UI no longer shows prior user's percentages while the new key is validating.
- `fetchUsage(force:)` — a user-initiated fetch waits up to 5s for a concurrent poll to finish, then proceeds. Previously a poll in flight would silently swallow the validate click.
- Retry loop treats `httpError(401|403)` as terminal with a clear "Session key rejected" message. No more 15s of red errors on a bad key.

**UsageHistoryStore.swift**
- `bindOptionalDate` now passes `SQLITE_TRANSIENT` so SQLite copies the string. The previous `SQLITE_STATIC` pattern with a local `let` was a use-after-free once the function returned (before `sqlite3_step` ran).

**SettingsView.swift, OnboardingView.swift**
- Both validation paths now call `usageStore.setSessionKey(...)` + `fetchUsage(force: true)` instead of writing Keychain directly. A single source of truth for identity changes.

### Verification performed

- `swift build -c release` — passes (10.84s, no warnings from my changes).
- Code review of each edit against its root cause — each fix addresses the mechanism, not the symptom.

### Not verified (manual testing required)

- End-to-end "paste new key" flow with a real claude.ai session. The build compiles, but the scenario involves live Cloudflare + API calls that can't be scripted here. Recommend testing before shipping a release:
  1. Run with key A, confirm data loads.
  2. Paste key B in Settings → Validate. Expect: UI clears instantly, fetches fresh org ID for B, shows B's data within ~5-10s (Cloudflare solve). No red-error intermediate state.
  3. Paste a bogus key → expect terminal "Session key rejected" message within ~3s, not 15s.

### Second-pass summary

All 16 audit items addressed (14 with code changes, 2 reviewed-and-closed).

### Third pass — real-world test reveals two more bugs

Testing against a real claude.ai account exposed issues the static audit missed.

**Bug R-1: `memberships[0]` is not always the usable org.**
User had 2 org memberships. Bootstrap succeeded; `/usage` returned 403 with
`{"type":"permission_error","message":"Invalid authorization for organization"}`.
The first membership was a team/shared org without usage-read permission; the
second was the user's personal org with full permission.

*Fix:* `fetchOrgIdsDirect` now returns *all* memberships sorted by role
priority (primary_owner → owner → admin → member → unknown). `fetchUsage`
iterates candidates until one returns 200, caches the winner for subsequent
polls, and falls back to re-iterating if the cached winner later loses
permission. Skips the just-failed org to avoid a redundant probe.

**Bug R-2: `URLSession.shared` leaked cookies across identities.**
`~/Library/HTTPStorages/<bundle>.binarycookies` persisted claude.ai auth
cookies across app launches AND between sessionKey swaps, because
`URLSession.shared`'s default HTTPCookieStorage accumulates every
`Set-Cookie` response.

*Fix:* switched to an ephemeral `URLSession` with `httpCookieAcceptPolicy =
.never`, `httpCookieStorage = nil`, `httpShouldSetCookies = false`. The
`Cookie` header is set manually on every request; URLSession no longer
accumulates or injects cookies on its own.

**Bug R-3 (found in final QA): race between setSessionKey and a concurrent fetchUsage.**
`setSessionKey` kicked off `purgeClaudeAIState()` as a Task, but callers
(`SettingsView.validateAndSave`) immediately started their own `fetchUsage`
Task. When the purge awaited, the fetch interleaved and read stale flags
(`webViewReady=true`, old `cachedOrgId`) from the previous identity.

*Fix:* `purgeClaudeAIState` now resets its in-memory flags synchronously at
the top of the function, before any await. `setSessionKey` also calls
`webClient.resetReadyState()` synchronously before launching the async
Task, so a concurrent fetch sees fresh state the moment `setSessionKey`
returns.

**Other R-pass improvements:**
- `purgeClaudeAIState()` now nukes *every* claude.ai cookie (not just
  `sessionKey`) plus WebKit disk storage for the domain.
- `clearSessionKey()` also calls the purge, same sync-before-async pattern.
- Non-200 `/usage` responses log the first 400 chars of the server body
  (behind `logger.error` — always on, DEBUG-gated file dumps still gated).

**Second-pass changes added to:**
- `AnthropicAPIClient.swift` — locale-agnostic Cloudflare detection, debug-dump gate, cached ISO formatters, non-focus-stealing WebView window.
- `UsageStore.swift` — init without didSet cascades, LaunchAgent via `/usr/bin/open -a`.
- `UsageHistoryStore.swift` — shared static ISO formatter.
- `GlobalShortcut.swift` — error-checked registration and defensive status-bar lookup.
- `ClaudeMeterProApp.swift` — single-instance NSAlert.

**Final build:** `swift build -c release` ✅ 9.62s clean.

### Files touched (both passes)

| File | Changes |
|---|---|
| `ClaudeMeterPro/AnthropicAPIClient.swift` | cachedOrgId invalidation, WKNavigation-token continuations, locale-safe CF detection, DEBUG-gated dump, cached formatters, non-stealing window |
| `ClaudeMeterPro/UsageStore.swift` | `setSessionKey` resets all per-identity state; `fetchUsage(force:)`; 401/403 terminal; init via `Published(initialValue:)`; `open -a` LaunchAgent |
| `ClaudeMeterPro/UsageHistoryStore.swift` | `SQLITE_TRANSIENT` binding; shared static ISO formatter |
| `ClaudeMeterPro/SettingsView.swift` | Routes through `setSessionKey` + `fetchUsage(force: true)` |
| `ClaudeMeterPro/OnboardingView.swift` | Routes through `setSessionKey` + `fetchUsage(force: true)` |
| `ClaudeMeterPro/GlobalShortcut.swift` | Status-checked registration; defensive status-bar walk |
| `ClaudeMeterPro/ClaudeMeterProApp.swift` | NSAlert on double-launch |
