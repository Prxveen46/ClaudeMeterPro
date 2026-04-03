# ClaudeMeter Pro — Next Steps Architecture

## Current State (v1.2.0 — April 3, 2026)

- macOS menu bar app (Swift/SwiftUI, macOS 13+)
- 9 menu bar styles, real-time usage tracking, session/daily/weekly bars
- SQLite usage history with charts, heatmap, predictions, notifications, CSV export
- Onboarding wizard, global shortcut (Cmd+Shift+U), shareable stats card
- DMG build script ready (`scripts/build-dmg.sh`) with version from AppVersion.swift
- Landing page ready (`landing/index.html`) — needs screenshot + store URL
- Unsigned (no Apple Developer account yet)

---

## Phase 1: Launch-Ready (Week 1)

**Goal:** Get the product live and purchasable.

### 1.1 Take App Screenshots
- Launch app, set up with real usage data
- Capture menu bar with each style at different usage levels
- Capture the popover (main view with bars + percentage)
- Capture the settings window (style picker, session key help)
- Save to `landing/screenshots/` and embed in landing page

### 1.2 Create Store Listing
- Sign up on **Gumroad** or **Lemon Squeezy**
- Upload DMG (`ClaudeMeterPro-v1.1.0.dmg`)
- Set price: **$9 one-time** (can adjust later)
- Write product description using landing page copy
- Update `landing/index.html` — replace `YOUR_STORE_URL` with real link

### 1.3 Deploy Landing Page
- Option A: Deploy `landing/` to Vercel (add to existing Vercel setup)
- Option B: Host on `prxveen.work/claudemeter` as a subdirectory
- Option C: Use a custom domain like `claudemeter.pro`
- Set up basic analytics (Plausible or Vercel Analytics — no cookies)

### 1.4 Update README — DONE
- Updated with new feature list, simplified for product focus
- Build-from-source still available, added DMG build instructions

---

## Phase 2: Trust & Polish (Week 2-3)

**Goal:** Remove friction for buyers. Build credibility.

### 2.1 Apple Developer Account ($99/yr)
- Enroll at developer.apple.com
- Generate "Developer ID Application" certificate
- Code-sign the app: `DEVELOPER_ID="Developer ID Application: Your Name" bash scripts/build-dmg.sh`
- Notarize: `xcrun notarytool submit ClaudeMeterPro-v1.1.0.dmg`
- **Impact:** Eliminates "unidentified developer" Gatekeeper warning — huge for conversions

### 2.2 Auto-Update System
- Implement Sparkle framework (https://sparkle-project.org/) for in-app updates
- Host appcast.xml on GitHub Pages or landing site
- Users get notified of new versions without re-downloading manually

### 2.3 Onboarding Flow — DONE
- 3-step wizard: Welcome → Session Key Setup → Tips
- Auto-advances on successful validation
- Only shown on first launch (UserDefaults flag)

### 2.4 CHANGELOG.md — DONE
- Created with full version history (v1.0.0 through v1.2.0)

---

## Phase 3: Feature Parity & Differentiation (Week 3-5)

**Goal:** Match competitor features, then exceed them.

### 3.1 Usage History & Charts — DONE
### 3.2 Smart Notifications — DONE
### 3.3 Usage Predictions — DONE
### 3.4 CSV Export — DONE

### 3.5 macOS Desktop Widgets
- WidgetKit integration for lock screen / notification center
- Compact widget: ring + percentage
- Detailed widget: percentage + bars + countdown

---

## Phase 4: Unique Advantages (Week 5+)

**Goal:** Features the competitor doesn't have.

### 4.1 Multiple Account Support
- Track usage across different Claude accounts (personal, work)
- Switch between accounts from menu bar

### 4.2 Keyboard Shortcut — DONE
- Cmd+Shift+U global hotkey via Carbon Event API

### 4.3 Usage Budgeting
- Set daily/weekly usage budgets
- Visual budget tracker alongside actual limits
- "Usage pace" indicator (ahead/behind budget)

### 4.4 Shareable Stats Card — DONE
- Branded dark card with percentage, bars, branding
- Copies to clipboard + save dialog (PNG)

### 4.5 iOS Companion App (Long-term)
- View usage history synced via iCloud
- Push notifications for limit warnings
- **Note:** Requires Apple Developer account + significant development effort

---

## Competitive Positioning vs "Usage for Claude"

See `COMPETITIVE-ANALYSIS.md` for full comparison.

**Our advantages to emphasize in marketing:**
- Works on macOS 13+ (competitor requires macOS 15 — excludes many users)
- 9 unique menu bar styles (competitor has basic display)
- Session key approach (no password sharing — more secure)
- Independent binary (no App Store dependency)

**Gaps to close:**
- Usage history & charts (Phase 3.1)
- Smart notifications (Phase 3.2)
- Predictions (Phase 3.3)
- iOS companion (Phase 4.5)

---

## Revenue Targets

| Milestone | Sales | Revenue |
|-----------|-------|---------|
| First sale | 1 | $9 |
| Break even (Apple Dev acct) | 11 | $99 |
| Ramen profitable | 100 | $900 |
| Sustainable side income | 500 | $4,500 |

**Pricing strategy:** Start at $9. Consider $12-15 after adding history/charts/widgets. Competitor is free but limited to macOS 15+ and closed source.

---

## Technical Debt to Address

1. **Version management** — DONE. Single source: `AppVersion.swift`, build script reads it via grep.
2. **Universal binary** — Currently arm64 only. Add `--arch x86_64` for Intel Mac support (uncomment in build-dmg.sh).
3. **API fragility** — Both this app and the competitor rely on claude.ai scraping. Monitor for Anthropic API changes. Consider official API if/when Anthropic offers usage endpoints.
4. **Entitlements** — Sandbox is disabled. For App Store distribution (future), sandboxing would need to be enabled with proper entitlements.
