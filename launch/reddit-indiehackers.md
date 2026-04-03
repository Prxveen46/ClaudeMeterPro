# r/IndieHackers Post

**Title:** $1 macOS menu bar app for Claude.ai users — from idea to Gumroad in 4 weeks

**Body:**

**What I built:** ClaudeMeter Pro — a macOS menu bar app that tracks your Claude.ai session, daily, and weekly usage in real time.

**The problem:** Claude Pro buries usage information deep in settings. I kept getting throttled mid-conversation with no warning. Checked Reddit — lots of people have the same frustration.

**Why $1?**
- Removes all purchase friction — cheaper than thinking about whether to buy it
- Signals "real software" vs. free abandonware
- Plan to raise to $2.99 after launch week, $4.99 after multi-account support
- Goal: volume and word-of-mouth over high margins

**Feature set:**
- 9 menu bar display styles
- Desktop widgets (WidgetKit)
- SQLite-backed usage history with charts and heatmaps
- Smart notifications + consumption-rate predictions
- CSV export
- Pure Swift/SwiftUI, zero dependencies
- Privacy-first: Keychain storage, no server, no analytics

**Distribution:**
- DMG built with a shell script (hardened runtime, notarization-ready)
- Sold on Gumroad
- Landing page on Vercel (single HTML file)

**What's next:**
- Multi-account support (for people with Pro + Team)
- Notification Center widgets
- Considering a free tier with limited features

Links:
- Gumroad: https://prxveen.gumroad.com/l/claudemeter
- Landing: https://claudemeterpro.vercel.app
- Source: https://github.com/Prxveen46/ClaudeMeterPro

AMA about the build, pricing, or distribution.

---

**Posting notes:**
- Best time: Thursday 9:00 AM ET (same day as r/SideProject)
- r/IndieHackers loves pricing strategy and business decisions
- Share revenue numbers if available
- Be transparent about costs (Apple Developer $99/yr, Vercel free tier, Gumroad 10%)
