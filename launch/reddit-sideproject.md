# r/SideProject Post

**Title:** I shipped a macOS menu bar app in 3 weeks and put it on Gumroad for $1

**Body:**

**The problem:** Claude Pro doesn't surface your usage limits clearly. I kept getting throttled mid-conversation with no warning.

**The solution:** ClaudeMeter Pro — a menu bar app that tracks your Claude.ai session, daily, and weekly usage in real time.

**The journey:**
- Week 1: Core app — SwiftUI menu bar extra, API polling, usage display
- Week 2: 9 menu bar styles, settings window, keychain storage
- Week 3: SQLite history, line charts, heatmaps, notifications, predictions, CSV export
- Week 4: Desktop widgets (WidgetKit), build pipeline, landing page

**Stack:** Pure Swift/SwiftUI, no external packages. SQLite via the C API built into macOS. CoreGraphics for custom menu bar icon rendering. WidgetKit for desktop widgets with App Group data sharing.

**Distribution:** DMG installer built with a shell script (hardened runtime + notarization-ready), sold on Gumroad for $1.

**Landing page:** Single HTML file with CSS mockups of the app UI, deployed to Vercel.

Landing page: https://claudemeterpro.vercel.app
Gumroad: https://prxveen.gumroad.com/l/claudemeter
Source: https://github.com/Prxveen46/ClaudeMeterPro

Happy to answer questions about the build process, Swift menu bar app development, or the distribution approach.

---

**Posting notes:**
- Best time: Thursday 9:00 AM ET
- r/SideProject loves the build journey narrative
- Include before/after or progress screenshots if possible
- Mention revenue/download numbers if available by launch day
