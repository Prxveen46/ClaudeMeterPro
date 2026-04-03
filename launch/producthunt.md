# Product Hunt Launch

**Tagline:** Know exactly how much Claude you have left.

**Description:**
ClaudeMeter Pro sits in your macOS menu bar and tracks your Claude.ai session, daily, and weekly usage in real time.

Choose from 9 menu bar styles. View usage history with interactive charts and activity heatmaps. Get smart notifications before you hit the limit. See predictions based on your consumption rate.

New: macOS desktop widgets show your usage at a glance — a small ring with countdown or a medium view with all three usage tiers.

Private by design — your session key stays in macOS Keychain, all history is stored locally in SQLite, and there's no server, no analytics, no telemetry.

$1 one-time purchase. macOS 13 or later (widgets require macOS 14+).

**Topics:** macOS, Developer Tools, Productivity, Artificial Intelligence

**First Comment (post within 60 seconds):**

Hey Product Hunt! I'm Praveen, and I built ClaudeMeter Pro because I was tired of getting throttled on Claude Pro without warning.

The idea is simple: your Claude usage should be as visible as your battery level. So I put it in the menu bar with 9 different display styles, and now desktop widgets too.

A few things I'm proud of:
- Pure Swift/SwiftUI with zero external dependencies
- SQLite history via the raw C API built into macOS
- CoreGraphics-rendered menu bar icons for pixel-perfect display
- WidgetKit integration with App Group data sharing

I'm planning to add multi-account support and notification center widgets next. Would love to hear what features you'd find useful!

**Maker Comment Templates:**

*For "how does it access usage data?"*
It uses your claude.ai session cookie. You paste it once in settings, and it's stored in macOS Keychain. The app polls Anthropic's usage endpoint locally — no proxy, no server in between.

*For "why not free?"*
$1 keeps the lights on and signals this is maintained software, not abandonware. No subscriptions, no ads, no upsells. All future updates included.

*For "will Anthropic break this?"*
Possible, but unlikely. The usage endpoint is part of their web app infrastructure. If it changes, I'll update the app. The session key approach is the same one their own web UI uses.

---

**Posting notes:**
- Launch day: Saturday 12:01 AM PT
- Respond to every comment within the first hour
- Have screenshots ready: menu bar, popover, history, widgets, settings
- Prepare a 30-second GIF showing the app in action
- Ask 2-3 friends to leave genuine comments early
