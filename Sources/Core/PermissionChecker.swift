import Foundation
import AppKit

final class PermissionChecker {
    static let shared = PermissionChecker()
    
    private init() {}
    
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
