import Foundation
import AppKit
import CoreGraphics

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
            print("[ClickInjector] Debounced \(button == .left ? "LEFT" : "RIGHT") click")
            return
        }
        
        lastClickTimes[button] = now
        
        let position = clickPositions[button] ?? getCurrentCursorPosition()
        
        print("[ClickInjector] Injecting \(button == .left ? "LEFT" : "RIGHT") click at \(position)")
        
        guard let mouseDown = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: button == .left ? .leftMouseDown : .rightMouseDown,
            mouseCursorPosition: position,
            mouseButton: button
        ) else {
            print("[ClickInjector] Failed to create mouseDown event")
            return
        }
        
        guard let mouseUp = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: button == .left ? .leftMouseUp : .rightMouseUp,
            mouseCursorPosition: position,
            mouseButton: button
        ) else {
            print("[ClickInjector] Failed to create mouseUp event")
            return
        }
        
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
        
        print("[ClickInjector] Click posted successfully")
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
