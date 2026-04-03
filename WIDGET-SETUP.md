# WidgetKit Extension Setup

macOS WidgetKit extensions require an Xcode project for proper bundling. The widget source code is ready in `ClaudeMeterWidget/` — follow these steps to enable it.

## Prerequisites

- macOS 14+ (Sonoma) — WidgetKit on Mac requires macOS 14
- Apple Developer account (for App Group provisioning)
- Xcode 15+

## Xcode Setup

### 1. Generate Xcode Project

```bash
swift package generate-xcodeproj
# or open Package.swift in Xcode directly
```

### 2. Add Widget Extension Target

1. In Xcode: **File → New → Target → Widget Extension**
2. Name: `ClaudeMeterWidget`
3. Uncheck "Include Configuration App Intent" (we use `StaticConfiguration`)
4. Delete the auto-generated files — use the existing sources in `ClaudeMeterWidget/`

### 3. Configure App Group

1. In Apple Developer Portal, create App Group: `group.com.claudemeterpro.shared`
2. Add it to both the main app and widget extension provisioning profiles
3. In Xcode, enable **App Groups** capability for both targets
4. Select `group.com.claudemeterpro.shared`

### 4. Add Shared Source

Both the main app target and widget extension target must include:
- `Shared/WidgetDataBridge.swift`

In Xcode, add `WidgetDataBridge.swift` to both target memberships.

### 5. Build & Test

1. Build the main app target first
2. Build the widget extension
3. Run the app — widgets become available in the macOS widget gallery

## Widget Families

| Family | Description |
|--------|-------------|
| **Small** | Usage ring with session percentage + countdown timer |
| **Medium** | Ring + session/daily/weekly usage bars with countdown |

## Data Flow

```
Main App (UsageStore)
  → fetchUsage() succeeds
  → pushToWidget() writes to App Group UserDefaults
  → WidgetCenter.shared.reloadAllTimelines()

Widget Extension
  → TimelineProvider reads from App Group UserDefaults
  → Renders current usage data
  → Auto-refreshes every 5 minutes
```
