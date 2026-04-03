# ClaudeMeter Pro

> Know exactly how much Claude you have left. Right from your menu bar.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)

---

## Overview

ClaudeMeter Pro sits in your macOS menu bar and tracks your Claude.ai usage in real time — session, daily, and weekly limits with live countdown timers, usage predictions, and history charts. No more guessing.

---

## Features

- **Real-time usage tracking** — live percentage and countdown for 5-hour session, daily, and weekly limits
- **9 menu bar styles** — Ring, Pill, Pulse Dot, Battery, Circular, Gauge, Segments, Dual Bar, Minimal
- **Usage history & charts** — interactive line chart with color-coded segments (5h to 90d range)
- **Activity heatmap** — GitHub-style contribution grid showing daily usage patterns
- **Smart notifications** — configurable alerts at 75%, 90%, and 100% thresholds
- **Usage predictions** — estimates time until limit based on consumption rate
- **CSV export** — export your usage history for personal analytics
- **Global shortcut** — Cmd+Shift+U to toggle the popover instantly
- **Shareable stats** — generate a branded image of your usage to share
- **Secure Keychain storage** — session key never stored in plain text
- **Launch at Login** — starts automatically when you log in
- **Onboarding wizard** — guided first-launch setup

---

## Requirements

- macOS 13 Ventura or later
- A Claude.ai account with an active subscription

---

## Installation

Download the latest DMG from the [releases page](https://github.com/Prxveen46/ClaudeMeterPro/releases) or build from source:

```bash
git clone https://github.com/Prxveen46/ClaudeMeterPro.git
cd ClaudeMeterPro
swift build -c release
```

To create a distributable DMG:

```bash
bash scripts/build-dmg.sh
```

---

## Setup

1. **Launch** ClaudeMeter Pro — a new icon appears in your menu bar
2. **Follow the onboarding wizard** or open Settings manually
3. **Find your session key** in your browser:
   - Open [claude.ai](https://claude.ai) and sign in
   - Open Developer Tools (Cmd+Option+I)
   - Go to Application → Cookies → claude.ai
   - Copy the value of the `sessionKey` cookie
4. **Paste** the key and click **Validate & Save**

> **First launch on unsigned builds:** Right-click the app → Open (macOS requires this once for apps downloaded outside the App Store).

---

## Privacy

- Session key stored exclusively in the **macOS Keychain**
- Network requests only to **claude.ai** for your own usage data
- No analytics, no telemetry, no third-party SDKs
- All history stored locally in SQLite on your machine

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

Built by [Prxveen.work](https://prxveen.work)
