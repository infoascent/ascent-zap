import AppKit

/// Studio-style vertical fader: tick scales on both sides, a slot, and a gradient cap.
/// `position` is 0 (bottom) ... 1 (top).
final class FaderView: NSView {
    enum Accent { case red, white }

    var accent: Accent = .white
    var active = false { didSet { needsDisplay = true } }
    var position: Double = 0 { didSet { needsDisplay = true } }
    var onChange: ((Double) -> Void)?
    var onRelease: (() -> Void)?

    // Geometry (points, flipped), measured from the reference.
    private let trackX: CGFloat = 62.5
    private let capTop: CGFloat = 17
    private let capBottom: CGFloat = 157
    private let capSize = NSSize(width: 52, height: 27.5)
    private let slotTop: CGFloat = 18
    private let slotBottom: CGFloat = 168
    private let tickTop: CGFloat = 23
    private let tickBottom: CGFloat = 164.5

    private var dragStartMouseY: CGFloat = 0
    private var dragStartPosition: Double = 0
    private var glide: Timer?

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var capCenterY: CGFloat { capBottom - CGFloat(position) * (capBottom - capTop) }

    private var capRect: NSRect {
        NSRect(x: trackX - capSize.width / 2, y: capCenterY - capSize.height / 2, width: capSize.width, height: capSize.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        drawTicks()
        drawSlot()
        drawCap()
    }

    private func drawTicks() {
        let step = (tickBottom - tickTop) / 10
        for i in 0...10 {
            let y = (tickTop + CGFloat(i) * step).rounded() + 0.5
            let major = i % 5 == 0
            (major ? Theme.tickMajor : Theme.tickMinor).setFill()
            let w: CGFloat = major ? 20 : 10
            NSRect(x: 0, y: y - 0.75, width: w, height: 1.5).fill()
            NSRect(x: bounds.width - w, y: y - 0.75, width: w, height: 1.5).fill()
        }
    }

    private func drawSlot() {
        let outer = NSRect(x: trackX - 6.5, y: slotTop - 4, width: 13, height: slotBottom - slotTop + 8)
        let slot = NSBezierPath(roundedRect: outer, xRadius: 4, yRadius: 4)
        Theme.well.setFill(); slot.fill()
        Theme.hairline.setStroke(); slot.lineWidth = 1; slot.stroke()

        let fillTop = capCenterY
        let fillRect = NSRect(x: trackX - 4, y: fillTop, width: 8, height: max(slotBottom - fillTop, 0))
        let fillColor: NSColor
        switch (accent, active) {
        case (.red, true): fillColor = Theme.red
        case (.white, true): fillColor = Theme.hex(0xD8D8D8)
        default: fillColor = Theme.hex(0x3A3A3A)
        }
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
        if active {
            NSGraphicsContext.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = fillColor.withAlphaComponent(0.55)
            glow.shadowBlurRadius = 6
            glow.set()
            fillColor.setFill(); fill.fill()
            NSGraphicsContext.restoreGraphicsState()
        } else {
            fillColor.setFill(); fill.fill()
        }
    }

    private func drawCap() {
        let r = capRect
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.shadowBlurRadius = 6
        shadow.set()
        let body = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
        Theme.hex(0x3C3C3C).setFill(); body.fill()
        NSGraphicsContext.restoreGraphicsState()

        // 4-stop gradient cap
        let g = NSGradient(colorsAndLocations:
            (Theme.hex(0x626262), 0.0), (Theme.hex(0x4E4E4E), 0.35),
            (Theme.hex(0x3E3E3E), 0.7), (Theme.hex(0x333333), 1.0))
        g?.draw(in: body, angle: 90)
        Theme.hex(0x6E6E6E, 0.6).setStroke()
        let edge = NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 3.5, yRadius: 3.5)
        edge.lineWidth = 1; edge.stroke()

        // indicator line
        let lineColor: NSColor
        switch (accent, active) {
        case (.red, true): lineColor = Theme.redBright
        case (.red, false): lineColor = Theme.hex(0xB0281F)
        case (.white, true): lineColor = Theme.textHi
        case (.white, false): lineColor = Theme.hex(0x9A9A9A)
        }
        lineColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: r.midX - 12, y: r.midY - 1.25, width: 24, height: 2.5), xRadius: 1.25, yRadius: 1.25).fill()
    }

    // MARK: Interaction

    private func positionFor(y: CGFloat) -> Double {
        Double(min(max((capBottom - y) / (capBottom - capTop), 0), 1))
    }

    override func mouseDown(with event: NSEvent) {
        glide?.invalidate()
        let p = convert(event.locationInWindow, from: nil)
        if !capRect.insetBy(dx: -4, dy: -4).contains(p) {
            set(positionFor(y: p.y))
        }
        dragStartMouseY = NSEvent.mouseLocation.y
        dragStartPosition = position
    }

    override func mouseDragged(with event: NSEvent) {
        // Screen coordinates keep tracking stable across monitors.
        let dy = NSEvent.mouseLocation.y - dragStartMouseY
        set(dragStartPosition + Double(dy / (capBottom - capTop)))
    }

    override func mouseUp(with event: NSEvent) { onRelease?() }

    override func scrollWheel(with event: NSEvent) {
        glide?.invalidate()
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.004 : event.scrollingDeltaY * 0.03
        set(position + Double(delta))
        if event.phase == .ended || event.momentumPhase == .ended || event.phase == [] { onRelease?() }
    }

    private func set(_ v: Double) {
        let v = min(max(v, 0), 1)
        position = v
        onChange?(v)
    }

    /// Smoothly glide to a value (used by presets).
    func glide(to target: Double, duration: Double = 0.28) {
        glide?.invalidate()
        let start = position
        let t0 = CACurrentMediaTime()
        glide = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            let k = min((CACurrentMediaTime() - t0) / duration, 1)
            let e = 1 - pow(1 - k, 3)
            self.set(start + (target - start) * e)
            if k >= 1 { t.invalidate(); self.onRelease?() }
        }
    }
}
