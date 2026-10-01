import AppKit
import CoreText

/// Brutalist black / red / white design system, measured from the reference popover.
enum Theme {
    static func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }

    static let header = hex(0x1C1C1C)
    static let panel = hex(0x0D0D0D)
    static let footer = hex(0x1A1A1A)
    static let hairline = hex(0x2A2A2A)
    static let border = hex(0x333333)
    static let well = hex(0x0A0A0A)

    static let red = hex(0xEC3326)
    static let redDeep = hex(0xA80B06)
    static let redBright = hex(0xFF2A1A)
    static let green = hex(0x2BE36B)
    static let amber = hex(0xF5A524)

    static let textHi = hex(0xF2F2F2)
    static let textMid = hex(0xA8A8A8)
    static let textLow = hex(0x7A7A7A)
    static let tickMajor = hex(0x5A5A5A)
    static let tickMinor = hex(0x353535)

    static let popoverSize = NSSize(width: 320, height: 540)

    static func registerFonts() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
        }
    }

    static func display(_ size: CGFloat, heavy: Bool = true) -> NSFont {
        NSFont(name: heavy ? "Anybody-ExtraBold" : "Anybody-Bold", size: size)
            ?? .systemFont(ofSize: size, weight: heavy ? .heavy : .bold)
    }

    static func mono(_ size: CGFloat, bold: Bool = true) -> NSFont {
        NSFont(name: bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    static func attr(_ s: String, _ font: NSFont, _ color: NSColor, kern: CGFloat = 0) -> NSAttributedString {
        NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: kern])
    }

    /// Draw text centered on a point.
    static func draw(_ a: NSAttributedString, centeredAt p: NSPoint) {
        let s = a.size()
        a.draw(at: NSPoint(x: p.x - s.width / 2, y: p.y - s.height / 2))
    }

    /// The ZAP lightning bolt: a slanted double stroke.
    static func bolt(in r: NSRect) -> NSBezierPath {
        let p = NSBezierPath()
        func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        // flipped coordinates: y grows downward
        p.move(to: pt(0.62, 0.0))
        p.line(to: pt(0.12, 0.62))
        p.line(to: pt(0.46, 0.50))
        p.line(to: pt(0.30, 1.0))
        p.line(to: pt(0.92, 0.30))
        p.line(to: pt(0.56, 0.42))
        p.close()
        return p
    }
}
