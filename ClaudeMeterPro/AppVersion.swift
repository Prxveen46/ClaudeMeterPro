import Foundation

/// Single source of truth for the app version.
/// build-dmg.sh reads this file via grep to stay in sync.
enum AppVersion {
    static let current = "1.2.0"
    static let display = "v\(current)"
}
