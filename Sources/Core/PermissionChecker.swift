import Foundation
import AppKit
import ApplicationServices

final class PermissionChecker {
    static let shared = PermissionChecker()
    
    private init() {}
    
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }
    
    var hasInputMonitoringPermission: Bool {
        let checkOptPrompt = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: checkOptPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    func requestAccessibilityPermission() {
    if AXIsProcessTrusted() {
        // Already granted - open settings anyway so user can see
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    } else {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
    
    func requestInputMonitoringPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    func checkAllPermissions() -> (accessibility: Bool, inputMonitoring: Bool) {
        return (hasAccessibilityPermission, hasInputMonitoringPermission)
    }
}
