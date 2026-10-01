import AppKit
import CoreGraphics

/// Color temperature math. Slider 0 = 6500K (neutral), slider 1 = 0K (pure red).
enum Kelvin {
    static let neutral = 6500.0
    static let tailStart = 2000.0

    static func fromSlider(_ w: Double) -> Double { neutral * (1 - min(max(w, 0), 1)) }
    static func toSlider(_ k: Double) -> Double { 1 - min(max(k, 0), neutral) / neutral }

    /// CIE 1931 xy of the Planckian locus (Kim et al. cubic approximation, 1667K-25000K).
    private static func xy(_ t: Double) -> (Double, Double) {
        let t = min(max(t, 1667), 25000)
        let x: Double
        if t <= 4000 {
            x = -0.2661239e9 / (t * t * t) - 0.2343589e6 / (t * t) + 0.8776956e3 / t + 0.179910
        } else {
            x = -3.0258469e9 / (t * t * t) + 2.1070379e6 / (t * t) + 0.2226347e3 / t + 0.240390
        }
        let y: Double
        if t <= 2222 {
            y = -1.1063814 * x * x * x - 1.34811020 * x * x + 2.18555832 * x - 0.20219683
        } else if t <= 4000 {
            y = -0.9549476 * x * x * x - 1.37418593 * x * x + 2.09137015 * x - 0.16748867
        } else {
            y = 3.0817580 * x * x * x - 5.87338670 * x * x + 3.75112997 * x - 0.37001483
        }
        return (x, y)
    }

    /// Linear sRGB of a blackbody at temperature t (Y = 1, unnormalized).
    private static func linearRGB(_ t: Double) -> (Double, Double, Double) {
        let (x, y) = xy(t)
        let X = x / y, Y = 1.0, Z = (1 - x - y) / y
        let r = 3.2406 * X - 1.5372 * Y - 0.4986 * Z
        let g = -0.9689 * X + 1.8758 * Y + 0.0415 * Z
        let b = 0.0557 * X - 0.2040 * Y + 1.0570 * Z
        return (r, g, b)
    }

    private static let white = linearRGB(neutral)

    /// Per-channel multipliers (gamma encoded, max channel = 1) relative to 6500K white.
    private static func curve(_ t: Double) -> (Double, Double, Double) {
        let c = linearRGB(t)
        var r = max(c.0 / white.0, 0), g = max(c.1 / white.1, 0), b = max(c.2 / white.2, 0)
        let m = max(r, g, b)
        r /= m; g /= m; b /= m
        let enc = { (v: Double) in pow(v, 1 / 2.2) }
        return (enc(r), enc(g), enc(b))
    }

    /// Multipliers for any kelvin in 0...6500. Below 2000K a smooth red tail eases into R=1, G=0, B=0.
    static func multipliers(_ k: Double) -> (r: Double, g: Double, b: Double) {
        if k >= neutral { return (1, 1, 1) }
        if k >= tailStart {
            let c = curve(k)
            return (c.0, c.1, c.2)
        }
        let base = curve(tailStart)
        let t = (tailStart - max(k, 0)) / tailStart
        let s = t * t * (3 - 2 * t)
        return (base.0 + (1 - base.0) * s, base.1 * (1 - s), base.2 * (1 - s))
    }
}

/// Writes gamma tables on every online display. The hardware backlight is untouched here;
/// dimming is a pure scale of the pixel values (see Backlight for PWM-Safe).
final class ColorEngine {
    static let shared = ColorEngine()

    private struct Table { var r: [CGGammaValue]; var g: [CGGammaValue]; var b: [CGGammaValue] }
    private var originals: [CGDirectDisplayID: Table] = [:]
    private var applied = false
    private var assertTimer: Timer?

    private init() {}

    func start() {
        // Start from a clean ColorSync state (also clears anything left by a crash).
        CGDisplayRestoreColorSyncSettings()
        captureNewDisplays()

        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            if flags.contains(.beginConfigurationFlag) { return }
            DispatchQueue.main.async { ColorEngine.shared.displaysChanged() }
        }, nil)

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in self.displaysChanged() }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in self.displaysChanged() }

        // Night Shift, True Tone or other apps can overwrite the tables: check and re-assert.
        assertTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in self.reassert() }
        apply()
    }

    static func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    private func captureNewDisplays() {
        for id in Self.onlineDisplays() where originals[id] == nil {
            if let t = readTable(id) { originals[id] = t }
        }
    }

    private func readTable(_ id: CGDirectDisplayID) -> Table? {
        let cap = CGDisplayGammaTableCapacity(id)
        guard cap > 0 else { return nil }
        var r = [CGGammaValue](repeating: 0, count: Int(cap))
        var g = r, b = r
        var n: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, cap, &r, &g, &b, &n) == .success, n > 0 else { return nil }
        return Table(r: Array(r.prefix(Int(n))), g: Array(g.prefix(Int(n))), b: Array(b.prefix(Int(n))))
    }

    private func target(for id: CGDirectDisplayID) -> Table? {
        guard let o = originals[id] else { return nil }
        let store = Store.shared
        let m = Kelvin.multipliers(store.kelvin)
        let br = Float(store.brightness)
        let mr = Float(m.r) * br, mg = Float(m.g) * br, mb = Float(m.b) * br
        return Table(r: o.r.map { $0 * mr }, g: o.g.map { $0 * mg }, b: o.b.map { $0 * mb })
    }

    /// Push the current Store state to every display.
    func apply() {
        captureNewDisplays()
        guard Store.shared.enabled else {
            if applied {
                CGDisplayRestoreColorSyncSettings()
                applied = false
            }
            return
        }
        for id in Self.onlineDisplays() {
            guard let t = target(for: id) else { continue }
            CGSetDisplayTransferByTable(id, UInt32(t.r.count), t.r, t.g, t.b)
        }
        applied = true
    }

    private func reassert() {
        guard Store.shared.enabled else { return }
        for id in Self.onlineDisplays() {
            guard let want = target(for: id), let have = readTable(id), have.r.count == want.r.count else {
                apply(); return
            }
            let i = want.r.count - 1
            if abs(have.r[i] - want.r[i]) > 0.004 || abs(have.g[i] - want.g[i]) > 0.004 || abs(have.b[i] - want.b[i]) > 0.004 {
                apply(); return
            }
        }
    }

    private func displaysChanged() {
        apply()
        // macOS sometimes resets gamma a beat after a reconfigure or wake.
        for delay in [0.5, 1.5, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.apply() }
        }
        Backlight.shared.displaysChanged()
    }

    /// Restore true colors (used on quit).
    func restore() {
        CGDisplayRestoreColorSyncSettings()
        applied = false
    }

    var displayCount: Int { Self.onlineDisplays().count }
}
