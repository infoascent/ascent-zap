import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let controller = PopoverController()
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ note: Notification) {
        Theme.registerFonts()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.target = self
            b.action = #selector(statusClicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.toolTip = "Ascent Zap"
        }

        popover.contentViewController = controller
        popover.contentSize = Theme.popoverSize
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.delegate = self

        ColorEngine.shared.start()
        Backlight.shared.start()
        Hotkey.shared.action = { Store.shared.enabled.toggle() }
        Hotkey.shared.sync()
        LoginItem.repairPath()

        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: Store.changed, object: nil)
        stateChanged()

        installSignalHandlers()

        // Auto-show the popover once, on the very first launch, so the icon is easy to find.
        if !Store.shared.launchedBefore {
            Store.shared.launchedBefore = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.showPopover() }
        }
    }

    @objc private func stateChanged() {
        ColorEngine.shared.apply()
        Backlight.shared.sync()
        Hotkey.shared.sync()
        statusItem.button?.image = StatusIcon.image(on: Store.shared.enabled)
    }

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        guard let e = NSApp.currentEvent else { return }
        if e.type == .rightMouseUp || e.modifierFlags.contains(.control) {
            showMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let b = statusItem.button else { return }
        // Clicking the icon also forces a re-apply (macOS can drop gamma after sleep).
        ColorEngine.shared.apply()
        controller.refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        paintPopoverChrome()
    }

    /// Color the popover frame (including the arrow) to match the header.
    private func paintPopoverChrome() {
        guard let frame = popover.contentViewController?.view.window?.contentView?.superview else { return }
        frame.wantsLayer = true
        frame.layer?.backgroundColor = Theme.header.cgColor
    }

    private func showMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: Store.shared.enabled ? "Turn ZAP Off" : "Turn ZAP On", action: #selector(toggleZap), keyEquivalent: "z")
        toggle.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About Ascent Zap", action: #selector(about), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Ascent Zap", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleZap() { Store.shared.enabled.toggle() }

    @objc private func openSettings() {
        showPopover()
        controller.setSettings(true)
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Ascent Zap",
            .credits: NSAttributedString(string: "Zero blue light. No PWM flicker.\nCalibrated display control for macOS."),
        ])
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func popoverDidClose(_ notification: Notification) { controller.setSettings(false) }

    func applicationWillTerminate(_ note: Notification) { restoreDisplays() }

    /// Settings revert the instant the app closes: true colors, original backlight, auto-brightness.
    private func restoreDisplays() {
        ColorEngine.shared.restore()
        Backlight.shared.restoreAll()
    }

    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in
                self?.restoreDisplays()
                exit(0)
            }
            src.resume()
            signalSources.append(src)
        }
    }
}

/// `--snapshot <dir>`: render the popover in several states to PNGs (design QA), touching no display.
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 {
    let dir = CommandLine.arguments[i + 1]
    _ = NSApplication.shared
    Theme.registerFonts()
    let s = Store.shared
    let c = PopoverController()
    func shot(_ name: String) {
        c.refresh()
        let v = c.view
        let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
    s.enabled = false; s.warmth = Kelvin.toSlider(6406); s.brightness = 1; s.pwmSafe = false
    shot("off")
    s.enabled = true; s.warmth = 1; s.brightness = 1; s.pwmSafe = true
    shot("night")
    s.warmth = Preset.evening.sliderValue; s.brightness = 0.45
    shot("evening")
    c.setSettings(true)
    shot("settings")
    exit(0)
}

// Single instance.
let bundleID = Bundle.main.bundleIdentifier ?? "com.infoascent.ascentzap"
if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
