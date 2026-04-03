# Show HN (Hacker News)

**Title:** Show HN: ClaudeMeter Pro – macOS menu bar app to track Claude.ai usage limits

**URL:** https://claudemeterpro.vercel.app

**First comment (post immediately after submission):**

Hey HN, I built this because I kept getting throttled on Claude Pro without realizing I was near the limit.

The web UI doesn't surface usage prominently, so I built a menu bar app that polls the usage API and shows:

- Real-time session/daily/weekly percentages with countdown
- Usage history stored in local SQLite with charts (5h–90d range)
- Predictions based on consumption rate
- Native macOS notifications at configurable thresholds
- Desktop widgets via WidgetKit (small: usage ring + countdown, medium: ring + tier bars)

Technical details: Pure Swift/SwiftUI, no external dependencies. Uses the claude.ai session cookie to hit their usage endpoint. Handles Cloudflare challenges with a WKWebView+URLSession hybrid approach. History in SQLite via the raw C API (`import SQLite3` on macOS).

9 different menu bar rendering styles — some use SF Symbols, others render custom NSImages via CoreGraphics for pixel-perfect menu bar display.

Widget data flows from the main app through App Group UserDefaults via a shared WidgetDataBridge module. Timeline refreshes on each API poll.

$1 on Gumroad: https://prxveen.gumroad.com/l/claudemeter

Source is on GitHub if you want to look at the code: https://github.com/Prxveen46/ClaudeMeterPro

---

**Posting notes:**
- Best time: Tuesday 8:30 AM ET
- URL field: landing page, NOT Gumroad
- Post the first comment within 60 seconds of submission
- Lead with technical details — HN rewards implementation depth
- Be ready for: "Why not just check the web UI?" and "Does Anthropic allow this?"
