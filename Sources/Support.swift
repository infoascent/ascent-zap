import AppKit
import Carbon.HIToolbox

enum Diagnostics {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Email-ready support bundle: version, OS, displays, filter state. Never anything personal.
    static func bundle() -> String {
        let s = Store.shared
        let bl = Backlight.shared
        var lines = [
            "Ascent Zap v\(version) feedback",
            "OS: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Arch: \(arch)",
            "Filter: \(s.enabled ? "ON" : "OFF"), warmth \(Int(s.kelvin))K, brightness \(Int(s.brightness * 100))%",
            "PWM-Safe: \(s.pwmSafe ? "ON" : "OFF"), supported: \(bl.isSupported)",
            "Hotkey: \(s.hotkeyEnabled ? "ON" : "OFF"), launch at login: \(LoginItem.enabled)",
        ]
        for id in ColorEngine.onlineDisplays() {
            let b = bl.brightness(id).map { "\(Int($0 * 100))%" } ?? "n/a"
            lines.append("Display \(id): \(CGDisplayPixelsWide(id))x\(CGDisplayPixelsHigh(id)), builtin \(CGDisplayIsBuiltin(id) != 0), backlight \(b), gamma cap \(CGDisplayGammaTableCapacity(id))")
        }
        return lines.joined(separator: "\n")
    }

    private static var arch: String {
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel"
        #endif
    }
}

/// Launch at login through a per-user LaunchAgent (works on macOS 12+, no helper app needed).
enum LoginItem {
    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.infoascent.ascentzap.plist")
    }

    static var enabled: Bool {
        get { FileManager.default.fileExists(atPath: plistURL.path) }
        set {
            if newValue {
                let plist: [String: Any] = [
                    "Label": "com.infoascent.ascentzap",
                    "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
                    "RunAtLoad": true,
                    "LimitLoadToSessionType": "Aqua",
                ]
                try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                (plist as NSDictionary).write(to: plistURL, atomically: true)
            } else {
                try? FileManager.default.removeItem(at: plistURL)
            }
        }
    }

    /// Keep the agent pointing at wherever the app currently lives.
    static func repairPath() {
        if enabled { enabled = true }
    }
}

/// Global ⌃⌥⌘Z hotkey via Carbon (no Accessibility permission needed).
final class Hotkey {
    static let shared = Hotkey()
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false
    var action: (() -> Void)?

    func sync() {
        if Store.shared.hotkeyEnabled { register() } else { unregister() }
    }

    private func register() {
        guard ref == nil else { return }
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { Hotkey.shared.action?() }
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        let id = EventHotKeyID(signature: OSType(0x415A4150), id: 1) // 'AZAP'
        RegisterEventHotKey(UInt32(kVK_ANSI_Z), UInt32(controlKey | optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &ref)
    }

    private func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}

/// Menu bar icon: bright red bolt when the filter is on, monochrome template when off.
enum StatusIcon {
    static func image(on: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 16)
        let img = NSImage(size: size, flipped: true) { r in
            let path = Theme.bolt(in: NSRect(x: 2, y: 0.5, width: 14, height: 15))
            (on ? Theme.redBright : NSColor.black).setFill()
            path.fill()
            return true
        }
        img.isTemplate = !on
        return img
    }
}
