// Renders the 1024px app icon: red bolt on a deep black squircle.
import AppKit
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size), flipped: true) { r in
    let inset = r.insetBy(dx: 100, dy: 100)
    let body = NSBezierPath(roundedRect: inset, xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(srgbRed: 0.13, green: 0.13, blue: 0.13, alpha: 1),
               ending: NSColor(srgbRed: 0.04, green: 0.04, blue: 0.04, alpha: 1))?.draw(in: body, angle: -90)
    NSColor(white: 0.25, alpha: 1).setStroke(); body.lineWidth = 6; body.stroke()
    let b = NSRect(x: 300, y: 250, width: 430, height: 520)
    let p = NSBezierPath()
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: b.minX + x * b.width, y: b.minY + y * b.height) }
    p.move(to: pt(0.62, 0)); p.line(to: pt(0.12, 0.62)); p.line(to: pt(0.46, 0.50))
    p.line(to: pt(0.30, 1)); p.line(to: pt(0.92, 0.30)); p.line(to: pt(0.56, 0.42)); p.close()
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowColor = NSColor(srgbRed: 1, green: 0.1, blue: 0.05, alpha: 0.8); s.shadowBlurRadius = 60; s.set()
    NSColor(srgbRed: 0.95, green: 0.12, blue: 0.07, alpha: 1).setFill(); p.fill()
    NSGraphicsContext.restoreGraphicsState()
    return true
}
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
