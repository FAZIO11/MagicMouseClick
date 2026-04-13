import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var isFirstLaunch = true
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        
        setupNotifications()
        
        if PermissionChecker.shared.hasAccessibilityPermission {
            MultitouchBridge.shared.start()
        } else if isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SetupWindowController.shared.showSetup()
            }
            isFirstLaunch = false
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MultitouchBridge.shared.stop()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .gesturesToggled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if SettingsManager.shared.gesturesEnabled {
                MultitouchBridge.shared.start()
            } else {
                MultitouchBridge.shared.stop()
            }
        }
    }
}
