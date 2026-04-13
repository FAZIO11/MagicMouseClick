import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var isFirstLaunch = true
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[MagicMouseClick] App launching...")
        menuBarController = MenuBarController()
        
        setupNotifications()
        
        print("[MagicMouseClick] Accessibility: \(PermissionChecker.shared.hasAccessibilityPermission)")
        
        startGestures()
        
        if !PermissionChecker.shared.hasAccessibilityPermission && isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SetupWindowController.shared.showSetup()
            }
            isFirstLaunch = false
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("[MagicMouseClick] App terminating, stopping bridge")
        MultitouchBridge.shared.stop()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .gesturesToggled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[MagicMouseClick] Gestures toggled: \(SettingsManager.shared.gesturesEnabled)")
            if SettingsManager.shared.gesturesEnabled {
                self?.startGestures()
            } else {
                MultitouchBridge.shared.stop()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[MagicMouseClick] App became active")
            if SettingsManager.shared.gesturesEnabled && PermissionChecker.shared.hasAccessibilityPermission {
                self?.startGestures()
            }
        }
    }
    
    private func startGestures() {
        print("[MagicMouseClick] Starting gestures...")
        MultitouchBridge.shared.start()
    }
}
