import Foundation
import AppKit

final class ClickInjector {
    static let shared = ClickInjector()
    
    private var lastClickTimes: [CGMouseButton: TimeInterval] = [:]
    private let debounceInterval: TimeInterval = 0.1
    private var clickPositions: [CGMouseButton: CGPoint] = [:]
    
    private init() {}
    
    func injectLeftClick() {
        injectClick(button: .left)
    }
    
    func injectRightClick() {
        injectClick(button: .right)
    }
    
    private func injectClick(button: CGMouseButton) {
        let now = CACurrentMediaTime()
        
        if let lastTime = lastClickTimes[button], now - lastTime < debounceInterval {
            return
        }
        
        lastClickTimes[button] = now
        
        let position = clickPositions[button] ?? getCurrentCursorPosition()
        
        let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: button == .left ? .leftMouseDown : .rightMouseDown,
            mouseCursorPosition: position,
            mouseButton: button
        )
        
        let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: button == .left ? .leftMouseUp : .rightMouseUp,
            mouseCursorPosition: position,
            mouseButton: button
        )
        
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    func updateClickPosition(_ position: CGPoint) {
        clickPositions[.left] = position
        clickPositions[.right] = position
    }
    
    private func getCurrentCursorPosition() -> CGPoint {
        guard let event = CGEvent(source: nil) else {
            return NSEvent.mouseLocation
        }
        return event.location
    }
    
    func reset() {
        lastClickTimes.removeAll()
        clickPositions.removeAll()
    }
}
