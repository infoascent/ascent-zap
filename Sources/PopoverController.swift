import AppKit

/// Header + panel + footer backdrop of the popover.
final class BackdropView: NSView {
    var showDivider = true { didSet { needsDisplay = true } }
    var title = "ASCENT ZAP" { didSet { needsDisplay = true } }
    var panelBottom: CGFloat = 354 { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Theme.footer.setFill(); bounds.fill()
        Theme.header.setFill(); NSRect(x: 0, y: 0, width: bounds.width, height: 54).fill()
        Theme.panel.setFill(); NSRect(x: 0, y: 54, width: bounds.width, height: panelBottom - 54).fill()
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSRect(x: 0, y: 53, width: bounds.width, height: 1).fill()
        Theme.hex(0x262626).setFill()
        NSRect(x: 0, y: panelBottom, width: bounds.width, height: 1).fill()
        if showDivider {
            Theme.hairline.setFill()
            NSRect(x: 159.5, y: 98.5, width: 1, height: 210).fill()
        }
        let t = Theme.attr(title, Theme.display(10.5), Theme.hex(0x8C8C8C), kern: 2.4)
        t.draw(at: NSPoint(x: 23.5, y: 27 - t.size().height / 2))
    }
}

final class LabelView: NSView {
    var text = "" { didSet { needsDisplay = true } }
    var color = Theme.textHi { didSet { needsDisplay = true } }
    var font = Theme.display(14.5)
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        Theme.draw(Theme.attr(text, font, color, kern: 0.1), centeredAt: NSPoint(x: bounds.midX, y: bounds.midY))
    }
}

final class TextBlock: NSView {
    var lines: [(String, NSColor)] = [] { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        var y: CGFloat = 0
        for (l, c) in lines {
            let a = Theme.attr(l, Theme.mono(9.5, bold: false), c, kern: 0.4)
            a.draw(at: NSPoint(x: 0, y: y))
            y += 15
        }
    }
}

final class PopoverController: NSViewController {
    private let store = Store.shared
    private let backdrop = BackdropView()

    // Main screen
    private let mainLayer = NSView()
    private let warmthLabel = LabelView()
    private let brightLabel = LabelView()
    private let warmthFader = FaderView()
    private let brightFader = FaderView()
    private let warmthBadge = BadgeView()
    private let brightBadge = BadgeView()
    private let pwmRow = ToggleRow()
    private var presetButtons: [(Preset, PresetButton)] = []
    private let zap = ZapButton()
    private let gear = IconButton()

    // Settings screen
    private let settingsLayer = NSView()
    private let loginRow = ToggleRow()
    private let hotkeyRow = ToggleRow()
    private let info = TextBlock()
    private let copyFeedback = ActionButton()
    private let restoreColors = ActionButton()
    private let quit = ActionButton()

    private var dragging = false
    private var showingSettings = false

    override func loadView() {
        let root = NSView(frame: NSRect(origin: .zero, size: Theme.popoverSize))
        backdrop.frame = root.bounds
        root.addSubview(backdrop)
        view = root
        buildMain()
        buildSettings()
        settingsLayer.isHidden = true

        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Store.changed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Backlight.changed, object: nil)
        refresh()
    }

    private func buildMain() {
        mainLayer.frame = view.bounds
        let host = FlippedView(frame: view.bounds)
        view.addSubview(host)
        host.addSubview(mainLayer)
        let m = FlippedView(frame: view.bounds)
        mainLayer.addSubview(m)

        gear.frame = NSRect(x: 272, y: 12, width: 30, height: 30)
        gear.onClick = { [weak self] in self?.setSettings(!(self?.showingSettings ?? false)) }
        host.addSubview(gear)

        warmthLabel.text = "WARMTH"
        warmthLabel.frame = NSRect(x: 26, y: 72, width: 120, height: 22)
        brightLabel.text = "BRIGHTNESS"
        brightLabel.frame = NSRect(x: 163, y: 72, width: 140, height: 22)

        warmthFader.accent = .red
        warmthFader.frame = NSRect(x: 23.5, y: 105, width: 125, height: 180)
        brightFader.accent = .white
        brightFader.frame = NSRect(x: 170.5, y: 105, width: 125, height: 180)

        warmthFader.onChange = { [weak self] v in self?.dragging = true; self?.store.warmth = v }
        warmthFader.onRelease = { [weak self] in self?.dragging = false; self?.refresh() }
        brightFader.onChange = { [weak self] v in
            self?.store.brightness = Store.brightnessFloor + v * (1 - Store.brightnessFloor)
        }

        warmthBadge.frame = NSRect(x: 36, y: 306, width: 100, height: 23)
        brightBadge.frame = NSRect(x: 183, y: 306, width: 100, height: 23)

        pwmRow.label = "PWM-SAFE MODE"
        pwmRow.frame = NSRect(x: 23.5, y: 367.5, width: 273, height: 31)
        pwmRow.onClick = { [weak self] in
            guard let self, Backlight.shared.isSupported else { return }
            self.store.pwmSafe.toggle()
        }

        let xs: [CGFloat] = [23.5, 118.5, 213.5]
        for (i, p) in Preset.allCases.enumerated() {
            let b = PresetButton()
            b.title = p.title
            b.frame = NSRect(x: xs[i], y: 419.5, width: 83, height: 31)
            b.onClick = { [weak self] in
                guard let self else { return }
                self.dragging = true
                self.warmthFader.glide(to: p.sliderValue)
            }
            presetButtons.append((p, b))
            m.addSubview(b)
        }

        zap.frame = NSRect(x: 23.5, y: 466, width: 273, height: 53)
        zap.onClick = { [weak self] in self?.store.enabled.toggle() }

        [warmthLabel, brightLabel, warmthFader, brightFader, warmthBadge, brightBadge, pwmRow, zap].forEach(m.addSubview)
    }

    private func buildSettings() {
        settingsLayer.frame = view.bounds
        let host = FlippedView(frame: view.bounds)
        view.addSubview(host, positioned: .below, relativeTo: view.subviews.last)
        host.addSubview(settingsLayer)
        let s = FlippedView(frame: view.bounds)
        settingsLayer.addSubview(s)

        loginRow.label = "LAUNCH AT LOGIN"
        loginRow.frame = NSRect(x: 23.5, y: 76, width: 273, height: 31)
        loginRow.onClick = { [weak self] in LoginItem.enabled.toggle(); self?.refresh() }

        hotkeyRow.label = "HOTKEY  ⌃⌥⌘Z"
        hotkeyRow.frame = NSRect(x: 23.5, y: 117, width: 273, height: 31)
        hotkeyRow.onClick = { [weak self] in self?.store.hotkeyEnabled.toggle() }

        info.frame = NSRect(x: 23.5, y: 168, width: 273, height: 150)

        copyFeedback.title = "COPY FEEDBACK FOR SUPPORT"
        copyFeedback.frame = NSRect(x: 23.5, y: 372, width: 273, height: 31)
        copyFeedback.onClick = { [weak self] in
            guard let self else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Diagnostics.bundle(), forType: .string)
            self.copyFeedback.flash = "COPIED TO CLIPBOARD"
            self.copyFeedback.needsDisplay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                self.copyFeedback.flash = nil; self.copyFeedback.needsDisplay = true
            }
        }

        restoreColors.title = "RESTORE TRUE COLORS"
        restoreColors.frame = NSRect(x: 23.5, y: 413, width: 273, height: 31)
        restoreColors.onClick = { [weak self] in
            self?.store.enabled = false
            ColorEngine.shared.restore()
        }

        quit.title = "QUIT ASCENT ZAP"
        quit.danger = true
        quit.frame = NSRect(x: 23.5, y: 466, width: 273, height: 53)
        quit.onClick = { NSApp.terminate(nil) }

        [loginRow, hotkeyRow, info, copyFeedback, restoreColors, quit].forEach(s.addSubview)
    }

    func setSettings(_ on: Bool) {
        showingSettings = on
        mainLayer.isHidden = on
        settingsLayer.isHidden = !on
        backdrop.showDivider = !on
        backdrop.title = on ? "SETTINGS" : "ASCENT ZAP"
        gear.symbol = on ? "xmark" : "gearshape.fill"
        gear.needsDisplay = true
        refresh()
    }

    @objc func refresh() {
        guard isViewLoaded else { return }
        let on = store.enabled

        // Faders and readouts
        if !dragging || abs(warmthFader.position - store.warmth) > 0.0001 { warmthFader.position = store.warmth }
        brightFader.position = (store.brightness - Store.brightnessFloor) / (1 - Store.brightnessFloor)
        warmthFader.active = on
        brightFader.active = on

        warmthLabel.color = Theme.red
        brightLabel.color = Theme.textHi

        let k = Int(store.kelvin.rounded())
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "en_US")
        warmthBadge.text = "\(f.string(from: NSNumber(value: k)) ?? "\(k)")K"
        warmthBadge.color = Theme.red
        brightBadge.text = "\(Int((store.brightness * 100).rounded()))%"
        brightBadge.color = Theme.textHi

        // PWM-Safe row
        let bl = Backlight.shared
        if bl.isSupported {
            pwmRow.label = "PWM-SAFE MODE"
            pwmRow.trailingText = nil
            pwmRow.isOn = store.pwmSafe
            switch store.pwmSafe ? .none : bl.warning {
            case .severe:
                pwmRow.dotOverride = Theme.red
                pwmRow.toolTip = "Backlight below 80%: it is likely flickering (PWM) and software dimming cannot help. Turn PWM-SAFE on."
            case .mild:
                pwmRow.dotOverride = Theme.amber
                pwmRow.toolTip = "Backlight below 100%: some panels flicker (PWM) here. PWM-SAFE pins it at 100% and dims in software."
            case .none:
                pwmRow.dotOverride = nil
                pwmRow.toolTip = "Pins the backlight at 100% so it never flickers, then dims in software."
            }
        } else {
            pwmRow.label = "SET BRIGHTNESS TO 100%"
            pwmRow.trailingText = "TIP"
            pwmRow.isOn = false
            pwmRow.dotOverride = nil
            pwmRow.toolTip = "This display does not expose backlight control. Set its hardware brightness to 100% and dim with the slider to avoid PWM flicker."
        }
        pwmRow.needsDisplay = true

        // Presets highlight only once the slider has settled.
        for (p, b) in presetButtons {
            b.filterOn = on
            if !dragging { b.selected = p.matches(store.warmth) }
        }
        zap.on = on

        // Settings
        loginRow.isOn = LoginItem.enabled
        loginRow.needsDisplay = true
        hotkeyRow.isOn = store.hotkeyEnabled
        hotkeyRow.needsDisplay = true
        if showingSettings {
            let displays = ColorEngine.onlineDisplays().count
            let ctrl = bl.controllableDisplays.count
            info.lines = [
                ("DISPLAYS        \(displays) online", Theme.textMid),
                ("BACKLIGHT CTRL  \(ctrl > 0 ? "\(ctrl) supported" : "none")", Theme.textMid),
                ("FILTER          \(on ? "ON" : "OFF")  ·  \(warmthBadge.text)  ·  \(brightBadge.text)", Theme.textMid),
                ("BRIGHTNESS      floor 10% (fixed on macOS)", Theme.textLow),
                ("", Theme.textLow),
                ("ZAP toggles the filter. Settings revert", Theme.textLow),
                ("instantly when the app quits.", Theme.textLow),
                ("", Theme.textLow),
                ("v\(Diagnostics.version)  ·  ASCENT ZAP · INFOASCENT", Theme.hex(0x555555)),
            ]
        }
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let v = super.hitTest(point)
        return v === self ? nil : v
    }
}
