import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    
    override init() {
        super.init()
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.click", accessibilityDescription: "MagicMouseClick")
        }
        
        let menu = NSMenu()
        
        let enableItem = NSMenuItem(
            title: SettingsManager.shared.gesturesEnabled ? "Disable Gestures" : "Enable Gestures",
            action: #selector(toggleGestures),
            keyEquivalent: "e"
        )
        enableItem.target = self
        menu.addItem(enableItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit MagicMouseClick", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleGestures() {
        SettingsManager.shared.gesturesEnabled.toggle()
        
        if let menu = statusItem?.menu,
           let enableItem = menu.items.first(where: { $0.title.hasPrefix("Enable") || $0.title.hasPrefix("Disable") }) {
            enableItem.title = SettingsManager.shared.gesturesEnabled ? "Disable Gestures" : "Enable Gestures"
        }
        
        NotificationCenter.default.post(name: .gesturesToggled, object: nil)
    }
    
    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let gesturesToggled = Notification.Name("gesturesToggled")
}
