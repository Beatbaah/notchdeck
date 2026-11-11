// Draws NotchDeck's app icon at every size macOS needs, then iconutil packs it.
// Run from the repo root:  swift tools/make-icon.swift && iconutil -c icns Support/AppIcon.iconset -o Support/AppIcon.icns
import AppKit

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let u = s / 1024 // design on a 1024 grid

    // macOS icon body: 824×824 squircle centred, with a soft drop shadow.
    let body = NSRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185 * u, yRadius: 185 * u)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24 * u
    shadow.shadowOffset = NSSize(width: 0, height: -10 * u)
    shadow.set()
    NSColor.black.setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // A night-sky screen: deep blue at the top fading to near-black.
    bodyPath.addClip()
    NSGradient(colors: [NSColor(srgbRed: 0.10, green: 0.16, blue: 0.30, alpha: 1),
                        NSColor(srgbRed: 0.03, green: 0.04, blue: 0.08, alpha: 1)])!
        .draw(in: body, angle: -90)

    // The notch, opened into a panel hanging from the top edge.
    let panel = NSRect(x: 232 * u, y: 470 * u, width: 560 * u, height: 454 * u)
    let panelPath = NSBezierPath()
    let r: CGFloat = 70 * u
    panelPath.move(to: NSPoint(x: panel.minX, y: panel.maxY))
    panelPath.line(to: NSPoint(x: panel.minX, y: panel.minY + r))
    panelPath.appendArc(withCenter: NSPoint(x: panel.minX + r, y: panel.minY + r), radius: r, startAngle: 180, endAngle: 270)
    panelPath.line(to: NSPoint(x: panel.maxX - r, y: panel.minY))
    panelPath.appendArc(withCenter: NSPoint(x: panel.maxX - r, y: panel.minY + r), radius: r, startAngle: 270, endAngle: 360)
    panelPath.line(to: NSPoint(x: panel.maxX, y: panel.maxY))
    panelPath.close()
    NSColor.black.setFill()
    panelPath.fill()

    // Three tiles: music (green), timer (orange), system (blue).
    let tileColors = [NSColor(srgbRed: 0.20, green: 0.84, blue: 0.47, alpha: 1),
                      NSColor(srgbRed: 1.00, green: 0.62, blue: 0.20, alpha: 1),
                      NSColor(srgbRed: 0.33, green: 0.62, blue: 1.00, alpha: 1)]
    let tileW: CGFloat = 148 * u, gap: CGFloat = 26 * u
    let startX = panel.midX - (3 * tileW + 2 * gap) / 2
    for (i, color) in tileColors.enumerated() {
        let tile = NSRect(x: startX + CGFloat(i) * (tileW + gap), y: panel.minY + 56 * u, width: tileW, height: 200 * u)
        let path = NSBezierPath(roundedRect: tile, xRadius: 34 * u, yRadius: 34 * u)
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = color.withAlphaComponent(0.7)
        glow.shadowBlurRadius = 30 * u
        glow.set()
        NSGradient(colors: [color, color.blended(withFraction: 0.35, of: .black)!])!.draw(in: path, angle: -90)
        NSGraphicsContext.restoreGraphicsState()
    }

    // The camera lens in the notch.
    let lens = NSRect(x: panel.midX - 22 * u, y: panel.maxY - 92 * u, width: 44 * u, height: 44 * u)
    NSColor(srgbRed: 0.10, green: 0.12, blue: 0.20, alpha: 1).setFill()
    NSBezierPath(ovalIn: lens).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Support/AppIcon.iconset")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
print("Wrote \(dir.path)")
