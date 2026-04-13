import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        
        if !PermissionChecker.shared.hasAccessibilityPermission {
            DispatchQueue.main.async {
                SetupWindowController.shared.showSetup()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MultitouchBridge.shared.stop()
    }
}
