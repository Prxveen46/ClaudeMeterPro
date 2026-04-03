# ClaudeMeter Pro — Launch Playbook

## Launch Week Schedule

| Day | Platform | Time (ET) | Action |
|-----|----------|-----------|--------|
| **Mon** | Email | Any | Pitch 9to5Mac Indie App Spotlight |
| **Tue** | Reddit + HN | 8:30 AM | Post r/macapps + Show HN simultaneously |
| **Tue** | Twitter/X | 9:30 AM | Launch thread |
| **Tue** | Bluesky | 10:00 AM | Cross-post thread |
| **Wed** | Reddit | 9:00 AM | Post r/ClaudeAI + r/ClaudeCode |
| **Thu** | Reddit | 9:00 AM | Post r/SideProject + r/IndieHackers |
| **Sat** | Product Hunt | 12:01 AM PT | Full PH launch |
| **All week** | Discord | Ongoing | Share in Anthropic Discord |

---

## Ready-to-Post Content

### 1. r/macapps Post

**Title:** I built a menu bar app to track Claude.ai usage — 9 styles, history charts, predictions ($1)

**Body:**

I kept hitting my Claude Pro usage limit without any warning. The web UI buries the usage info deep in settings, and by the time I check, I'm already throttled.

So I built ClaudeMeter Pro — a macOS menu bar app that shows your session, daily, and weekly usage in real time.

**What it does:**
- Live percentage + countdown timer in the menu bar
- 9 menu bar styles (ring, pill, dot, battery, gauge, etc.)
- Usage history with line charts and activity heatmaps
- Smart notifications at 75%, 90%, 100%
- Predictions — "Limit in ~2h 15m" based on your consumption rate
- CSV export for your own analytics
- Cmd+Shift+U global shortcut

**Privacy:** Session key stored in macOS Keychain. No analytics, no telemetry, no server. Everything stays on your Mac.

**Requires:** macOS 13+ and a Claude.ai subscription.

**$1 one-time purchase:** https://prxveen.gumroad.com/l/claudemeter

Landing page: https://claudemeterpro.vercel.app

Happy to answer any questions or take feedback.

---

### 2. Show HN (Hacker News)

**Title:** Show HN: ClaudeMeter Pro – macOS menu bar app to track Claude.ai usage limits

**URL:** https://claudemeterpro.vercel.app

**First comment (post immediately after submission):**

Hey HN, I built this because I kept getting throttled on Claude Pro without realizing I was near the limit.

The web UI doesn't surface usage prominently, so I built a menu bar app that polls the usage API and shows:

- Real-time session/daily/weekly percentages with countdown
- Usage history stored in local SQLite with charts (5h–90d range)
- Predictions based on consumption rate
- Native macOS notifications at configurable thresholds

Technical details: Pure Swift/SwiftUI, no external dependencies. Uses the claude.ai session cookie to hit their usage endpoint. Handles Cloudflare challenges with a WKWebView+URLSession hybrid approach. History in SQLite via the raw C API (import SQLite3 on macOS).

9 different menu bar rendering styles — some use SF Symbols, others render custom NSImages via CoreGraphics for pixel-perfect menu bar display.

$1 on Gumroad: https://prxveen.gumroad.com/l/claudemeter

Source is on GitHub if you want to look at the code: https://github.com/Prxveen46/ClaudeMeterPro

---

### 3. Twitter/X Thread

**Tweet 1 (Hook):**
I kept hitting my Claude Pro usage limit with zero warning.

So I built a macOS menu bar app that tracks it in real time.

ClaudeMeter Pro — $1, one-time purchase. 🧵

**Tweet 2 (Screenshot):**
It sits in your menu bar and shows:
→ Session, daily, and weekly usage %
→ Live countdown to reset
→ 9 different display styles

[attach screenshot of menu bar + popover]

**Tweet 3 (History):**
Built-in usage history with color-coded charts.

View 5 hours to 90 days of data. Activity heatmap shows your daily patterns.

Export to CSV if you want to analyze it yourself.

[attach screenshot of history tab]

**Tweet 4 (Smart features):**
Smart notifications at 75%, 90%, 100%.

Usage predictions: "Limit in ~2h 15m" based on your current pace.

Cmd+Shift+U toggles the popover from anywhere.

**Tweet 5 (CTA):**
$1. One-time. No subscription. All future updates included.

macOS 13+ required.

→ https://prxveen.gumroad.com/l/claudemeter
→ https://claudemeterpro.vercel.app

If you use Claude Pro and hate flying blind on usage, this is for you.

---

### 4. r/ClaudeAI Post

**Title:** I got tired of hitting the usage limit without warning, so I built a menu bar tracker

**Body:**

Anyone else get frustrated by how buried the usage info is on claude.ai?

I built a macOS menu bar app that polls your usage and shows session/daily/weekly percentages with a live countdown. It also tracks your usage history over time so you can see your patterns.

Some things it does:
- 9 menu bar styles (pick what fits your setup)
- Usage history charts from 5 hours to 90 days
- Notifications when you're approaching limits (75%, 90%, 100%)
- Predicts when you'll hit the limit based on your pace
- All data stored locally — no server, no analytics

It uses your session cookie from claude.ai (you paste it once in settings). Everything runs locally on your Mac.

$1 on Gumroad: https://prxveen.gumroad.com/l/claudemeter

Requires macOS 13 or later. Would love feedback from fellow Claude power users.

---

### 5. r/SideProject Post

**Title:** I shipped a macOS menu bar app in 3 weeks and put it on Gumroad for $1

**Body:**

**The problem:** Claude Pro doesn't surface your usage limits clearly. I kept getting throttled mid-conversation with no warning.

**The solution:** ClaudeMeter Pro — a menu bar app that tracks your Claude.ai session, daily, and weekly usage in real time.

**The journey:**
- Week 1: Core app — SwiftUI menu bar extra, API polling, usage display
- Week 2: 9 menu bar styles, settings window, keychain storage
- Week 3: SQLite history, line charts, heatmaps, notifications, predictions, CSV export

**Stack:** Pure Swift/SwiftUI, no external packages. SQLite via the C API built into macOS. CoreGraphics for custom menu bar icon rendering.

**Distribution:** DMG installer built with a shell script, sold on Gumroad for $1.

**Landing page:** Built as a single HTML file with CSS mockups of the app UI, deployed to Vercel.

Landing page: https://claudemeterpro.vercel.app
Gumroad: https://prxveen.gumroad.com/l/claudemeter
Source: https://github.com/Prxveen46/ClaudeMeterPro

Happy to answer questions about the build process, Swift menu bar app development, or the distribution approach.

---

### 6. 9to5Mac Pitch Email

**To:** michaelb@9to5mac.com
**Subject:** Indie App Spotlight: ClaudeMeter Pro — menu bar usage tracker for Claude.ai

Hi Michael,

I built ClaudeMeter Pro, a macOS menu bar app that tracks Claude.ai usage in real time — session, daily, and weekly limits with live countdowns, history charts, and smart notifications.

**Why it exists:** Claude Pro doesn't surface usage limits clearly. Power users get throttled mid-conversation without warning.

**What makes it different:**
- 9 menu bar display styles (ring, pill, gauge, etc.)
- SQLite-backed usage history with interactive charts
- Consumption-rate predictions ("Limit in ~2h 15m")
- macOS 13+ (the main competitor requires macOS 15)
- $1 one-time on Gumroad

**Links:**
- Landing page: https://claudemeterpro.vercel.app
- Gumroad: https://prxveen.gumroad.com/l/claudemeter
- GitHub: https://github.com/Prxveen46/ClaudeMeterPro

Happy to provide screenshots, a press kit, or answer any questions.

Best,
Praveen Kumar
https://prxveen.work

---

### 7. Product Hunt Tagline & Description

**Tagline:** Know exactly how much Claude you have left.

**Description:**
ClaudeMeter Pro sits in your macOS menu bar and tracks your Claude.ai session, daily, and weekly usage in real time.

Choose from 9 menu bar styles. View usage history with interactive charts and activity heatmaps. Get smart notifications before you hit the limit. See predictions based on your consumption rate.

Private by design — your session key stays in macOS Keychain, all history is stored locally in SQLite, and there's no server, no analytics, no telemetry.

$1 one-time purchase. macOS 13 or later.

**Topics:** macOS, Developer Tools, Productivity, Artificial Intelligence

---

## Pricing Strategy

**Launch price:** $1 (current)
**After launch week:** Consider raising to $2.99 with framing: "Launch price was $1. Now $2.99 — still less than a coffee."
**After adding widgets/multi-account:** $4.99

The $1 price removes all purchase friction and encourages word-of-mouth. Raise it once you have reviews and traction.

---

## Key Rules

1. **r/ClaudeAI and r/ClaudeCode** — Frame as "I built this for myself" not "buy my product"
2. **Hacker News** — Lead with technical details in your first comment
3. **Twitter** — Use thread format with screenshots, not a single link tweet
4. **Product Hunt** — Respond to every comment within the first hour
5. **All platforms** — Never cold-promote. Engage authentically first.
6. **Screenshots matter** — Every post should include a visual of the app in action
