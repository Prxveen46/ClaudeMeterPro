# ClaudeMeter Pro

> A lightweight macOS menu bar app to monitor your Claude.ai 5-hour session usage in real time.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Overview

ClaudeMeter Pro sits quietly in your macOS menu bar and shows you exactly how much of your current Claude.ai 5-hour usage window you have consumed, along with a live countdown to the next reset. No more guessing — just glance at the menu bar and get back to work.

---

## Features

- **Real-time usage tracking** — fetches your Claude.ai session usage and displays the percentage consumed in the current 5-hour window
- **Live countdown timer** — shows the time remaining until your session resets (e.g. `1h 42m`)
- **Multiple menu bar icon styles** — choose from Battery, Circular, Minimal, Segments, Dual Bar, or Gauge
- **Configurable refresh interval** — poll every 1, 2, 5, or 10 minutes
- **Secure session key storage** — your session key is stored in the macOS Keychain, never in plain text
- **Launch at Login** — optionally start ClaudeMeter Pro automatically when you log in
- **Zero background overhead** — countdown ticks only while the popover is open; polling uses a lightweight timer

---

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ / Swift 5.9+ (to build from source)
- A Claude.ai account with an active subscription

---

## Installation

### Build from Source

```bash
git clone https://github.com/Prxveen46/ClaudeMeterPro.git
cd ClaudeMeterPro
swift build -c release
```

Or open the package in Xcode:

```bash
open Package.swift
```

Then press **⌘R** to run, or use **Product → Archive** to create a release build.

---

## Setup

1. **Launch** ClaudeMeter Pro — a new icon will appear in your menu bar.
2. **Click** the menu bar icon and select **Settings**.
3. **Find your session key** in your browser:
   - Open [claude.ai](https://claude.ai) in Chrome/Safari/Firefox.
   - Open DevTools → Application → Cookies → `claude.ai`.
   - Copy the value of the `sessionKey` cookie (it starts with `sk-ant-sid...`).
4. **Paste** the key into the *Session Key* field in Settings and click **Validate & Save**.
5. ClaudeMeter Pro will immediately fetch your usage and begin polling.

---

## Usage

| Menu Bar State | Meaning |
|---|---|
| `⚠ Setup` | No session key configured |
| `...` | Fetching usage data |
| `65% | 1h 42m` | 65% used, resets in 1 h 42 m |
| `⚠ Error` | Could not reach Claude.ai |

Click the menu bar icon to open the popover, which shows:

- A large percentage readout (turns red above 90%)
- An animated progress bar
- A live "resets in" countdown
- Quick access to Settings and Quit

---

## Project Structure

```
ClaudeMeterPro/
├── ClaudeMeterProApp.swift      # App entry point, NSStatusItem & popover setup
├── ContentView.swift            # Menu bar popover UI
├── SettingsView.swift           # Settings window (session key, style, interval)
├── UsageStore.swift             # Observable state, polling, menu bar label
├── AnthropicAPIClient.swift     # Network layer — fetches usage from Claude.ai
├── KeychainHelper.swift         # Secure session key storage via Keychain
├── Info.plist                   # App metadata
└── ClaudeMeterPro.entitlements  # Sandbox & network entitlements
Package.swift                    # Swift Package Manager manifest
```

---

## Privacy & Security

- Your session key is stored exclusively in the **macOS Keychain**.
- The app makes network requests only to **claude.ai** to fetch your own usage data.
- No analytics, no telemetry, no third-party SDKs.

---

## Contributing

Pull requests are welcome! Please open an issue first to discuss significant changes.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m 'Add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgements

Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/) on macOS.
