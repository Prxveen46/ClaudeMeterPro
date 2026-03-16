#!/usr/bin/env swift
import AppKit

func createIcon(size: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let s = CGFloat(size)

    // Background: dark rounded rect
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.04, dy: s * 0.04), xRadius: s * 0.22, yRadius: s * 0.22)
    NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1).setFill()
    bgPath.fill()

    // Subtle gradient overlay
    let gradient = NSGradient(colors: [
        NSColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1),
        NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    ])
    gradient?.draw(in: bgPath, angle: -45)

    // Circular progress ring (background)
    let center = NSPoint(x: s * 0.5, y: s * 0.52)
    let radius = s * 0.28
    let ringWidth = s * 0.06

    let bgRing = NSBezierPath()
    bgRing.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    bgRing.lineWidth = ringWidth
    NSColor(white: 1, alpha: 0.1).setStroke()
    bgRing.stroke()

    // Circular progress ring (filled ~65%)
    let progressRing = NSBezierPath()
    progressRing.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 234, clockwise: true)
    progressRing.lineWidth = ringWidth
    progressRing.lineCapStyle = .round

    // Blue-to-cyan gradient effect (approximate with solid blue)
    NSColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 1).setStroke()
    progressRing.stroke()

    // Percentage text
    let percentStr = "65" as NSString
    let fontSize = s * 0.18
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let textSize = percentStr.size(withAttributes: attrs)
    let textOrigin = NSPoint(
        x: center.x - textSize.width / 2,
        y: center.y - textSize.height / 2
    )
    percentStr.draw(at: textOrigin, withAttributes: attrs)

    // "%" symbol
    let pctStr = "%" as NSString
    let pctFont = NSFont.systemFont(ofSize: s * 0.09, weight: .medium)
    let pctAttrs: [NSAttributedString.Key: Any] = [
        .font: pctFont,
        .foregroundColor: NSColor(white: 1, alpha: 0.6)
    ]
    let pctSize = pctStr.size(withAttributes: pctAttrs)
    pctStr.draw(at: NSPoint(
        x: textOrigin.x + textSize.width + s * 0.01,
        y: center.y - pctSize.height / 2 + s * 0.03
    ), withAttributes: pctAttrs)

    // App name at bottom
    let nameStr = "ClaudeMeter" as NSString
    let nameFont = NSFont.systemFont(ofSize: s * 0.07, weight: .semibold)
    let nameAttrs: [NSAttributedString.Key: Any] = [
        .font: nameFont,
        .foregroundColor: NSColor(white: 1, alpha: 0.5)
    ]
    let nameSize = nameStr.size(withAttributes: nameAttrs)
    nameStr.draw(at: NSPoint(
        x: s * 0.5 - nameSize.width / 2,
        y: s * 0.12
    ), withAttributes: nameAttrs)

    img.unlockFocus()
    return img
}

// Generate iconset
let iconsetPath = "/Users/praveenkumar/ClaudeCode/Apps/ClaudeMeterPro/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes {
    let img = createIcon(size: size)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }

    // Standard size
    if size <= 512 {
        let path = "\(iconsetPath)/icon_\(size)x\(size).png"
        try! png.write(to: URL(fileURLWithPath: path))
    }

    // @2x size (half the pixel size name)
    let halfSize = size / 2
    if halfSize >= 16 && halfSize <= 512 {
        let path2x = "\(iconsetPath)/icon_\(halfSize)x\(halfSize)@2x.png"
        try! png.write(to: URL(fileURLWithPath: path2x))
    }
}

print("Iconset generated at \(iconsetPath)")
