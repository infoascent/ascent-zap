import Foundation

/// Persisted user state. Every change posts `Store.changed` so the UI and the
/// display engine stay in sync without knowing about each other.
final class Store {
    static let shared = Store()
    static let changed = Notification.Name("AscentZapStoreChanged")

    private let d = UserDefaults.standard

    private init() {
        d.register(defaults: [
            "warmth": 0.0,
            "brightness": 1.0,
            "enabled": false,
            "pwmSafe": false,
            "hotkeyEnabled": true,
            "launchedBefore": false,
        ])
    }

    /// 0 = neutral 6500K, 1 = pure red 0K.
    var warmth: Double {
        get { d.double(forKey: "warmth") }
        set { d.set(min(max(newValue, 0), 1), forKey: "warmth"); notify() }
    }

    /// Software brightness, 0.1 ... 1.0.
    var brightness: Double {
        get { d.double(forKey: "brightness") }
        set { d.set(min(max(newValue, Store.brightnessFloor), 1), forKey: "brightness"); notify() }
    }

    var enabled: Bool {
        get { d.bool(forKey: "enabled") }
        set { d.set(newValue, forKey: "enabled"); notify() }
    }

    var pwmSafe: Bool {
        get { d.bool(forKey: "pwmSafe") }
        set { d.set(newValue, forKey: "pwmSafe"); notify() }
    }

    var hotkeyEnabled: Bool {
        get { d.bool(forKey: "hotkeyEnabled") }
        set { d.set(newValue, forKey: "hotkeyEnabled"); notify() }
    }

    var launchedBefore: Bool {
        get { d.bool(forKey: "launchedBefore") }
        set { d.set(newValue, forKey: "launchedBefore") }
    }

    static let brightnessFloor = 0.10

    var kelvin: Double { Kelvin.fromSlider(warmth) }

    private func notify() {
        NotificationCenter.default.post(name: Store.changed, object: self)
    }
}

enum Preset: CaseIterable {
    case day, evening, night

    var title: String {
        switch self {
        case .day: return "DAY"
        case .evening: return "EVENING"
        case .night: return "NIGHT"
        }
    }

    var kelvin: Double {
        switch self {
        case .day: return 4000
        case .evening: return 2700
        case .night: return 0
        }
    }

    var sliderValue: Double { Kelvin.toSlider(kelvin) }

    /// A preset reads as active when the slider sits within 2% of it.
    func matches(_ warmth: Double) -> Bool { abs(warmth - sliderValue) <= 0.02 }
}
