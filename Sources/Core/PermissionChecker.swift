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
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    func requestInputMonitoringPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    func checkAllPermissions() -> (accessibility: Bool, inputMonitoring: Bool) {
        return (hasAccessibilityPermission, hasInputMonitoringPermission)
    }
}
