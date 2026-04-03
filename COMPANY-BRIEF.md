# ClaudeMeter Pro — Company Brief

## Company

**Name:** ClaudeMeter Pro
**Founded by:** Praveen Kumar (Prxveen.work)
**Type:** Solo indie software product
**Website:** https://claudemeterpro.vercel.app
**Store:** https://prxveen.gumroad.com/l/claudemeter
**Source:** https://github.com/Prxveen46/ClaudeMeterPro

---

## What We Sell

A $1 macOS menu bar app that tracks Claude.ai usage in real time — session, daily, and weekly limits with live countdowns, usage history charts, smart notifications, and consumption-rate predictions.

---

## The Problem We Solve

Claude Pro users pay $20/month but have no clear visibility into their usage limits. The web UI buries usage data deep in settings. Users get throttled mid-conversation without warning, losing productivity and flow. There is no native tool from Anthropic that surfaces this information at a glance.

---

## Our Product

**ClaudeMeter Pro v1.2.0** — Native macOS menu bar app (Swift/SwiftUI)

**Core Features:**
- 9 menu bar display styles (ring, pill, dot, battery, circular, gauge, segments, dual bar, minimal)
- Real-time session, daily, and weekly usage percentages with live countdown timers
- SQLite-backed usage history with interactive line charts (5h to 90d range)
- GitHub-style activity heatmap showing daily usage patterns
- Smart notifications at configurable thresholds (75%, 90%, 100%)
- Usage predictions — estimates time until limit based on consumption rate
- CSV export for personal analytics
- Shareable branded stats card (PNG)
- Global keyboard shortcut (Cmd+Shift+U)
- First-launch onboarding wizard
- Secure session key storage in macOS Keychain

**Privacy:** No analytics, no telemetry, no server. All data stays on the user's Mac.

**Requirements:** macOS 13 Ventura or later. Claude.ai subscription.

**Price:** $1 one-time purchase. Free updates forever.

---

## Target Audience

**Primary:** Claude.ai power users — developers, writers, researchers, and AI-assisted professionals who regularly approach or hit their usage limits and want real-time visibility without opening the browser.

**Secondary:** Indie developers and Mac power users who value well-crafted menu bar utilities.

**Audience size:** r/ClaudeAI has 688K members. Claude Pro has millions of subscribers globally. The overlap of "power users who hit limits" is our addressable market.

---

## Competitive Landscape

**Direct competitor:** "Usage for Claude" by Amir Hayek — free, Mac App Store + iOS companion

| Advantage | ClaudeMeter Pro | Competitor |
|-----------|:-:|:-:|
| macOS 13+ support | Yes | No (requires macOS 15) |
| Menu bar styles | 9 options | 1 |
| Auth method | Session key (no password) | Full login |
| Open source | Yes | No |
| Price | $1 | Free |
| Usage history | Yes | Yes |
| iOS companion | No | Yes |

**Our positioning:** Works on more Macs, more customizable, more secure auth, open source transparency. The $1 price signals "real product with ongoing development" vs free which may stall.

---

## Mission

**Make Claude.ai usage limits invisible.** Every Claude Pro user should know exactly how much capacity they have left without thinking about it — at a glance from their menu bar, with predictions and alerts before they hit the wall.

---

## Goals

### Short-term (30 days)
- **100 paid downloads** — validate product-market fit
- **Launch on 5+ platforms** — Reddit (r/ClaudeAI, r/macapps, r/SideProject), Hacker News, Product Hunt, Twitter, Anthropic Discord
- **Get featured** on 9to5Mac Indie App Spotlight or similar editorial
- **Collect 10+ reviews** on Gumroad for social proof
- **Break even** on Apple Developer account cost ($99) = 99 sales

### Medium-term (90 days)
- **500 paid downloads** — $500 revenue
- **Raise price to $2.99** after launch-week momentum with "introductory price was $1" framing
- **Add macOS desktop widgets** (WidgetKit) — parity feature with competitor
- **Add multi-account support** — track personal + work Claude accounts
- **Code sign + notarize** — eliminate Gatekeeper friction, boost conversions
- **Get 25+ Gumroad reviews** — social proof drives organic discovery

### Long-term (6-12 months)
- **2,000+ lifetime downloads** — sustainable side income
- **Price at $4.99** with expanded feature set (widgets, multi-account, budgeting)
- **iOS companion app** — view usage from iPhone via iCloud sync
- **Explore App Store distribution** — broader reach, but 30% fee trade-off
- **Build email list** — direct channel for updates and future products
- **Monthly revenue target: $500+** from new sales + price increases

---

## Revenue Model

| Phase | Price | Target Sales | Revenue |
|-------|-------|-------------|---------|
| Launch (Week 1) | $1 | 100 | $100 |
| Post-launch (Month 2-3) | $2.99 | 200 | $598 |
| Mature (Month 4+) | $4.99 | 100/month | $499/month |

**Distribution:** Gumroad (currently). Future: direct website sales, potentially Mac App Store.
**Cost structure:** Near-zero marginal cost. Only fixed costs: Apple Developer account ($99/yr), Vercel (free tier), Gumroad (10% fee).

---

## Brand Voice

- **Tone:** Direct, technical, no-nonsense. Speak like a developer to developers.
- **Personality:** The tool that just works. No hype, no fluff. Built by someone who had the same problem.
- **Key phrases:** "Know exactly how much Claude you have left." / "Right from your menu bar." / "No analytics, no telemetry, no server."
- **Never say:** "Revolutionary", "game-changing", "powered by AI", or any marketing fluff. The product speaks for itself.

---

## Distribution Channels (ranked by priority)

1. **r/ClaudeAI** — 688K members, exact target audience
2. **r/macapps** — 172K members, allows self-promotion
3. **Hacker News Show HN** — Technical audience, high upside
4. **Twitter/X** — Build-in-public thread format
5. **Product Hunt** — Weekend launch for lower vote threshold
6. **9to5Mac Indie App Spotlight** — Editorial multiplier
7. **Anthropic Discord** — 79K members, official community
8. **r/SideProject** — 647K members, builder community
9. **Bluesky** — Growing developer audience, cross-post from Twitter

---

## Assets

| Asset | Location |
|-------|----------|
| Landing page | https://claudemeterpro.vercel.app |
| Gumroad store | https://prxveen.gumroad.com/l/claudemeter |
| GitHub repo | https://github.com/Prxveen46/ClaudeMeterPro |
| DMG installer | `scripts/build-dmg.sh` → `ClaudeMeterPro-v1.2.0.dmg` |
| Launch playbook | `LAUNCH-PLAYBOOK.md` (ready-to-post content for all platforms) |
| Competitive analysis | `COMPETITIVE-ANALYSIS.md` |
| Roadmap | `NEXT-STEPS.md` |
| Changelog | `CHANGELOG.md` |
