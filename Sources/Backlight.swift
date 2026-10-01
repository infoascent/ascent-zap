import Foundation
import CoreGraphics

/// PWM-Safe Mode: pins the hardware backlight of Apple-controlled panels to 100%
/// through the private DisplayServices framework, so the backlight driver never
/// enters its pulsing (PWM) range. Dimming then happens in software (gamma).
final class Backlight {
    static let shared = Backlight()
    static let changed = Notification.Name("AscentZapBacklightChanged")

    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanFn = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias ALCSetFn = @convention(c) (CGDirectDisplayID, Bool) -> Int32
    private typealias ALCGetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Bool>) -> Int32

    private var getB: GetFn?
    private var setB: SetFn?
    private var canB: CanFn?
    private var setALC: ALCSetFn?
    private var getALC: ALCGetFn?
    private var hasALC: CanFn?

    /// Brightness before the lock, restored when PWM-Safe turns off or the app quits.
    private var prior: [CGDirectDisplayID: Float] = [:]
    /// Auto-brightness state before launch, restored on quit.
    private var priorALC: [CGDirectDisplayID: Bool] = [:]
    private var locked = false
    private var timer: Timer?

    enum Warning { case none, mild, severe }

    private init() {
        guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) else { return }
        func sym<T>(_ name: String, _: T.Type) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }
        getB = sym("DisplayServicesGetBrightness", GetFn.self)
        setB = sym("DisplayServicesSetBrightness", SetFn.self)
        canB = sym("DisplayServicesCanChangeBrightness", CanFn.self)
        setALC = sym("DisplayServicesEnableAmbientLightCompensation", ALCSetFn.self)
        getALC = sym("DisplayServicesAmbientLightCompensationEnabled", ALCGetFn.self)
        hasALC = sym("DisplayServicesHasAmbientLightCompensation", CanFn.self)
    }

    /// Displays whose backlight we can drive (built-in panels, Studio Display, Pro Display XDR).
    var controllableDisplays: [CGDirectDisplayID] {
        guard let canB, getB != nil, setB != nil else { return [] }
        return ColorEngine.onlineDisplays().filter { canB($0) }
    }

    var isSupported: Bool { !controllableDisplays.isEmpty }

    func brightness(_ id: CGDirectDisplayID) -> Float? {
        guard let getB else { return nil }
        var v: Float = 0
        return getB(id, &v) == 0 ? v : nil
    }

    func start() {
        // Auto-brightness is held off while the app runs so it cannot fight the slider or the lock.
        for id in controllableDisplays {
            guard let hasALC, hasALC(id), let getALC, let setALC else { continue }
            var on = false
            if getALC(id, &on) == 0 { priorALC[id] = on }
            _ = setALC(id, false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in self.tick() }
        sync()
    }

    /// Bring the hardware in line with Store.pwmSafe.
    func sync() {
        let want = Store.shared.pwmSafe && isSupported
        if want && !locked { lock() }
        if !want && locked { unlock() }
    }

    private func lock() {
        for id in controllableDisplays {
            if prior[id] == nil, let b = brightness(id) { prior[id] = b }
            _ = setB?(id, 1.0)
        }
        locked = true
    }

    private func unlock() {
        for (id, b) in prior { _ = setB?(id, b) }
        prior.removeAll()
        locked = false
    }

    /// Every 2 s: re-pin the backlight if a brightness key or the system moved it.
    private func tick() {
        sync()
        defer { NotificationCenter.default.post(name: Backlight.changed, object: nil) }
        guard locked else { return }
        for id in controllableDisplays {
            if prior[id] == nil, let b = brightness(id) { prior[id] = b }
            if let b = brightness(id), b < 0.999 { _ = setB?(id, 1.0) }
        }
    }

    func displaysChanged() {
        if locked { for id in controllableDisplays { _ = setB?(id, 1.0) } }
    }

    /// Honest flicker warning: a backlight below 100% is likely pulsing; below 80% software dimming cannot help.
    var warning: Warning {
        guard !locked else { return .none }
        let levels = controllableDisplays.compactMap { brightness($0) }
        guard let lowest = levels.min() else { return .none }
        if lowest < 0.8 { return .severe }
        if lowest < 0.995 { return .mild }
        return .none
    }

    func restoreAll() {
        if locked { unlock() }
        for (id, on) in priorALC { _ = setALC?(id, on) }
        priorALC.removeAll()
    }
}
