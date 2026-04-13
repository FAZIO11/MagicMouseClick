import Foundation

final class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let gesturesEnabled = "gesturesEnabled"
        static let tapDuration = "tapDuration"
        static let movementThreshold = "movementThreshold"
        static let showVisualizer = "showVisualizer"
        static let launchAtLogin = "launchAtLogin"
    }
    
    var gesturesEnabled: Bool {
        get { defaults.object(forKey: Keys.gesturesEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.gesturesEnabled) }
    }
    
    var tapDuration: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.tapDuration)
            return value > 0 ? value : 0.18
        }
        set { defaults.set(newValue, forKey: Keys.tapDuration) }
    }
    
    var movementThreshold: Float {
        get {
            let value = defaults.float(forKey: Keys.movementThreshold)
            return value > 0 ? value : 0.03
        }
        set { defaults.set(newValue, forKey: Keys.movementThreshold) }
    }
    
    var showVisualizer: Bool {
        get { defaults.bool(forKey: Keys.showVisualizer) }
        set { defaults.set(newValue, forKey: Keys.showVisualizer) }
    }
    
    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            AutoLaunchManager.shared.isEnabled = newValue
        }
    }
}
