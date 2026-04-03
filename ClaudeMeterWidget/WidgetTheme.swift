import SwiftUI

/// Widget-safe version of ClaudeTheme (no NSColor dependency).
/// Mirrors the main app's color palette for visual consistency.
enum WidgetTheme {
    static let amber = Color(red: 0.87, green: 0.56, blue: 0.34)
    static let calm = Color(red: 0.35, green: 0.75, blue: 0.65)
    static let moderate = Color(red: 0.87, green: 0.56, blue: 0.34)
    static let warning = Color(red: 0.92, green: 0.45, blue: 0.35)
    static let critical = Color(red: 0.82, green: 0.22, blue: 0.22)

    static func usageColor(percent: Int) -> Color {
        let p = Double(min(max(percent, 0), 100))
        if p < 50 {
            let t = p / 50.0
            return blend(calm, moderate, t: t)
        } else if p < 80 {
            let t = (p - 50.0) / 30.0
            return blend(moderate, warning, t: t)
        } else {
            let t = (p - 80.0) / 20.0
            return blend(warning, critical, t: t)
        }
    }

    static func usageGradient(percent: Int) -> LinearGradient {
        let endColor = usageColor(percent: percent)
        let startColor = usageColor(percent: max(0, percent - 20))
        return LinearGradient(
            colors: [startColor.opacity(0.85), endColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private static func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        let t = min(max(t, 0), 1)
        // Extract known RGB values since we define our own colors
        let aComps = components(of: a)
        let bComps = components(of: b)
        return Color(
            red: aComps.r + (bComps.r - aComps.r) * t,
            green: aComps.g + (bComps.g - aComps.g) * t,
            blue: aComps.b + (bComps.b - aComps.b) * t
        )
    }

    private static func components(of color: Color) -> (r: Double, g: Double, b: Double) {
        // Map known colors to their RGB values
        if color == calm { return (0.35, 0.75, 0.65) }
        if color == moderate { return (0.87, 0.56, 0.34) }
        if color == warning { return (0.92, 0.45, 0.35) }
        if color == critical { return (0.82, 0.22, 0.22) }
        return (0.5, 0.5, 0.5)
    }
}
