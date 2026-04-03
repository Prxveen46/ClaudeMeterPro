# Changelog

All notable changes to ClaudeMeter Pro will be documented in this file.

## [1.2.0] — 2026-04-03

### Added
- **Usage History & Charts** — SQLite-backed history with interactive line charts and time range selection (5h, 24h, 7d, 30d, 90d)
- **Activity Heatmap** — GitHub-style contribution grid showing daily usage patterns
- **Smart Notifications** — Configurable alerts at 75%, 90%, and 100% usage thresholds
- **Usage Predictions** — Estimates time until limit based on current consumption rate
- **CSV Export** — Export usage history with ISO8601 timestamps
- **History Tab** — New tab in Settings for viewing charts, heatmap, and data stats
- **Session Key Help** — Step-by-step guide for finding your session key
- **Onboarding Flow** — First-launch welcome with setup wizard
- **Global Keyboard Shortcut** — Cmd+Shift+U to toggle the popover
- **Shareable Stats Card** — Generate a branded image of your usage stats

### Changed
- Pill and Pulse preview cards now show full "65% | 2h 30m" matching actual menu bar display
- Removed GitHub link from About page

### Fixed
- VS Code launch.json uses `${workspaceFolder}` for single-folder compatibility

## [1.1.0] — 2026-04-03

### Added
- DMG build script (`scripts/build-dmg.sh`) with optional code signing
- Landing page (`landing/index.html`) with Claude-branded dark theme

## [1.0.2] — 2026-03-17

### Added
- DMG installer process
- App icon

## [1.0.0] — 2026-03-16

### Added
- Initial release
- 9 menu bar styles (ring, pill, dot, battery, circular, minimal, segments, dual bar, gauge)
- Real-time usage tracking with live countdown timer
- Session, daily, and weekly usage bars
- Configurable refresh intervals (1-10 minutes)
- Secure Keychain storage for session key
- Launch at Login
- Claude-branded UI with warm amber theme
