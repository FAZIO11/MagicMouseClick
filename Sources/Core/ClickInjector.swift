import Foundation
import AppKit

final class ClickInjector {
    static let shared = ClickInjector()
    
    private init() {}
    
    func injectLeftClick() {
        guard let currentLocation = CGEvent(source: nil)?.location else { return }
        injectClick(at: currentLocation, button: .left)
    }
    
    func injectRightClick() {
        guard let currentLocation = CGEvent(source: nil)?.location else { return }
        injectClick(at: currentLocation, button: .right)
    }
    
    private func injectClick(at location: CGPoint, button: CGMouseButton) {
        let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: button == .left ? .leftMouseDown : .rightMouseDown,
            mouseCursorPosition: location,
            mouseButton: button
        )
        
        let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: button == .left ? .leftMouseUp : .rightMouseUp,
            mouseCursorPosition: location,
            mouseButton: button
        )
        
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
}
