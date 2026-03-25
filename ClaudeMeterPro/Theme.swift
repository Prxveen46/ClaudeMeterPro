import SwiftUI

// MARK: - Claude-branded color palette

enum ClaudeTheme {
    // Primary warm amber — the signature accent
    static let amber = Color(red: 0.87, green: 0.56, blue: 0.34)
    static let amberLight = Color(red: 0.94, green: 0.72, blue: 0.52)
    static let amberDark = Color(red: 0.72, green: 0.42, blue: 0.22)

    // Usage severity spectrum
    static let calm = Color(red: 0.35, green: 0.75, blue: 0.65)       // teal-green
    static let moderate = Color(red: 0.87, green: 0.56, blue: 0.34)   // amber
    static let warning = Color(red: 0.92, green: 0.45, blue: 0.35)    // coral
    static let critical = Color(red: 0.82, green: 0.22, blue: 0.22)   // deep red

    // Surfaces
    static let cardFill = Color.gray.opacity(0.06)
    static let cardBorder = Color.gray.opacity(0.12)
    static let subtleGlow = Color(red: 0.87, green: 0.56, blue: 0.34).opacity(0.4)

    /// Smooth color interpolation across the 0-100% usage range.
    static func usageColor(percent: Int) -> Color {
        let p = Double(min(max(percent, 0), 100))
        if p < 50 {
            // calm teal → amber
            let t = p / 50.0
            return blend(calm, moderate, t: t)
        } else if p < 80 {
            // amber → coral
            let t = (p - 50.0) / 30.0
            return blend(moderate, warning, t: t)
        } else {
            // coral → deep red
            let t = (p - 80.0) / 20.0
            return blend(warning, critical, t: t)
        }
    }

    /// Bar gradient using the usage spectrum.
    static func usageGradient(percent: Int) -> LinearGradient {
        let endColor = usageColor(percent: percent)
        let startColor = usageColor(percent: max(0, percent - 20))
        return LinearGradient(
            colors: [startColor.opacity(0.85), endColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Helpers

    private static func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        let t = min(max(t, 0), 1)
        // Resolve to sRGB components
        let ac = NSColor(a).usingColorSpace(.sRGB) ?? NSColor(a)
        let bc = NSColor(b).usingColorSpace(.sRGB) ?? NSColor(b)

        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ac.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        bc.getRed(&br, green: &bg, blue: &bb, alpha: &ba)

        return Color(
            red: ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue: ab + (bb - ab) * t
        )
    }
}
