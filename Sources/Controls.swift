import AppKit

/// Base for the custom drawn controls: hover + press tracking and a click handler.
class PressableView: NSView {
    var onClick: (() -> Void)?
    var hovered = false { didSet { needsDisplay = true } }
    var pressed = false { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func mouseDown(with event: NSEvent) { pressed = true }
    override func mouseUp(with event: NSEvent) {
        pressed = false
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// DAY / EVENING / NIGHT key.
final class PresetButton: PressableView {
    var title = ""
    var selected = false { didSet { needsDisplay = true } }
    var filterOn = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5).offsetBy(dx: 0, dy: pressed ? 1 : 0)
        NSGraphicsContext.saveGraphicsState()
        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(pressed ? 0.3 : 0.75)
        s.shadowOffset = NSSize(width: 0, height: pressed ? -1 : -3)
        s.shadowBlurRadius = pressed ? 2 : 5
        s.set()
        let body = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
        Theme.hex(0x202020).setFill(); body.fill()
        NSGraphicsContext.restoreGraphicsState()

        let top: NSColor, bottom: NSColor, text: NSColor
        if selected && filterOn {
            top = Theme.hex(0x5A0805); bottom = Theme.hex(0x3A0402); text = Theme.redBright
        } else if selected {
            top = Theme.hex(0x464646); bottom = Theme.hex(0x333333); text = Theme.textHi
        } else {
            top = hovered ? Theme.hex(0x2C2C2C) : Theme.hex(0x262626)
            bottom = hovered ? Theme.hex(0x202020) : Theme.hex(0x1B1B1B)
            text = hovered ? Theme.hex(0xC8C8C8) : Theme.textMid
        }
        NSGradient(starting: top, ending: bottom)?.draw(in: body, angle: 90)
        Theme.hex(0x3A3A3A, selected ? 0.9 : 0.5).setStroke()
        body.lineWidth = 1; body.stroke()
        Theme.draw(Theme.attr(title, Theme.display(11, heavy: false), text, kern: 0.2),
                   centeredAt: NSPoint(x: r.midX, y: r.midY))
    }
}

/// The big ZAP key. Glows red when the filter is on.
final class ZapButton: PressableView {
    var on = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1).offsetBy(dx: 0, dy: pressed ? 1 : 0)
        let body = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)

        NSGraphicsContext.saveGraphicsState()
        let s = NSShadow()
        if on {
            s.shadowColor = Theme.red.withAlphaComponent(pressed ? 0.35 : 0.6)
            s.shadowBlurRadius = 14
        } else {
            s.shadowColor = NSColor.black.withAlphaComponent(0.8)
            s.shadowOffset = NSSize(width: 0, height: pressed ? -1 : -4)
            s.shadowBlurRadius = pressed ? 3 : 8
        }
        s.set()
        (on ? Theme.redDeep : Theme.hex(0x1E1E1E)).setFill(); body.fill()
        NSGraphicsContext.restoreGraphicsState()

        let text: NSColor
        if on {
            NSGradient(colorsAndLocations: (Theme.hex(0xE41C10), 0), (Theme.hex(0xC4110A), 0.55), (Theme.hex(0x9A0904), 1))?
                .draw(in: body, angle: 90)
            Theme.hex(0xFF5A4E, 0.7).setStroke()
            text = Theme.hex(0xFFF1EF)
        } else {
            NSGradient(starting: hovered ? Theme.hex(0x2A2A2A) : Theme.hex(0x252525),
                       ending: hovered ? Theme.hex(0x1E1E1E) : Theme.hex(0x1A1A1A))?.draw(in: body, angle: 90)
            Theme.hex(0x363636).setStroke()
            text = hovered ? Theme.hex(0xB5B5B5) : Theme.hex(0x8E8E8E)
        }
        body.lineWidth = 1; body.stroke()

        let label = Theme.attr("ZAP", Theme.display(14), text, kern: 2.2)
        let ls = label.size()
        let boltSize = NSSize(width: 22, height: 19)
        let total = boltSize.width + 10 + ls.width
        let x0 = r.midX - total / 2
        text.setFill()
        Theme.bolt(in: NSRect(x: x0, y: r.midY - boltSize.height / 2, width: boltSize.width, height: boltSize.height)).fill()
        label.draw(at: NSPoint(x: x0 + boltSize.width + 10, y: r.midY - ls.height / 2))
    }
}

/// PWM-SAFE MODE row: status dot, label, ON/OFF.
final class ToggleRow: PressableView {
    var label = ""
    var isOn = false { didSet { needsDisplay = true } }
    var dotOverride: NSColor? { didSet { needsDisplay = true } }
    var trailingText: String?

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let box = NSBezierPath(rect: r)
        Theme.hex(hovered ? 0x141414 : 0x101010).setFill(); box.fill()
        (isOn ? Theme.green.withAlphaComponent(0.75) : Theme.border).setStroke()
        box.lineWidth = 1; box.stroke()

        let dot = dotOverride ?? (isOn ? Theme.green : Theme.hex(0x5E5E5E))
        if isOn || dotOverride != nil {
            NSGraphicsContext.saveGraphicsState()
            let g = NSShadow(); g.shadowColor = dot.withAlphaComponent(0.8); g.shadowBlurRadius = 5; g.set()
            dot.setFill(); NSBezierPath(ovalIn: NSRect(x: 10, y: r.midY - 4, width: 8, height: 8)).fill()
            NSGraphicsContext.restoreGraphicsState()
        } else {
            dot.setFill(); NSBezierPath(ovalIn: NSRect(x: 10, y: r.midY - 4, width: 8, height: 8)).fill()
        }

        let t = Theme.attr(label, Theme.mono(10.5), isOn ? Theme.textHi : Theme.hex(0xC4C4C4), kern: 1.1)
        t.draw(at: NSPoint(x: 26, y: r.midY - t.size().height / 2))

        let state = trailingText ?? (isOn ? "ON" : "OFF")
        let st = Theme.attr(state, Theme.mono(10.5), isOn ? Theme.green : Theme.textLow, kern: 1.1)
        st.draw(at: NSPoint(x: r.maxX - 11 - st.size().width, y: r.midY - st.size().height / 2))
    }
}

/// Small framed value readout under each fader.
final class BadgeView: NSView {
    var text = "" { didSet { needsDisplay = true } }
    var color = Theme.textHi { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let a = Theme.attr(text, Theme.mono(12.5), color)
        let w = max(a.size().width + 18, 40)
        let r = NSRect(x: (bounds.width - w) / 2, y: 0.5, width: w, height: bounds.height - 1)
        let p = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
        Theme.well.setFill(); p.fill()
        Theme.border.setStroke(); p.lineWidth = 1; p.stroke()
        Theme.draw(a, centeredAt: NSPoint(x: r.midX, y: r.midY))
    }
}

/// Icon button (gear / back) in the header.
final class IconButton: PressableView {
    var symbol = "gearshape.fill"

    override func draw(_ dirtyRect: NSRect) {
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        guard let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
        let tint = hovered ? Theme.hex(0xBDBDBD) : Theme.hex(0x7C7C7C)
        let tinted = NSImage(size: img.size, flipped: false) { rect in
            img.draw(in: rect)
            tint.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        let s = tinted.size
        tinted.draw(in: NSRect(x: (bounds.width - s.width) / 2, y: (bounds.height - s.height) / 2, width: s.width, height: s.height))
    }
}

/// Flat full-width action key used in Settings.
final class ActionButton: PressableView {
    var title = ""
    var danger = false
    var flash: String?

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5).offsetBy(dx: 0, dy: pressed ? 1 : 0)
        let p = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
        NSGradient(starting: Theme.hex(hovered ? 0x2C2C2C : 0x262626), ending: Theme.hex(hovered ? 0x202020 : 0x1B1B1B))?.draw(in: p, angle: 90)
        (danger ? Theme.red.withAlphaComponent(0.6) : Theme.hex(0x3A3A3A)).setStroke()
        p.lineWidth = 1; p.stroke()
        let color = flash != nil ? Theme.green : (danger ? Theme.red : Theme.hex(0xC8C8C8))
        Theme.draw(Theme.attr(flash ?? title, Theme.mono(10.5), color, kern: 1.0), centeredAt: NSPoint(x: r.midX, y: r.midY))
    }
}
