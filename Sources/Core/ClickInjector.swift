import Foundation
import AppKit
import CoreGraphics

final class ClickInjector {
    static let shared = ClickInjector()
    
    private var clickPositions: [CGMouseButton: CGPoint] = [:]
    
    private var lastClickTime: TimeInterval = 0
    private var lastClickPosition: CGPoint = .zero
    private let doubleClickTime: TimeInterval = 0.5
    private let doubleClickDistance: CGFloat = 20.0
    
    private init() {}
    
    func injectLeftClick() {
        injectClick(button: .left)
    }
    
    func injectRightClick() {
        injectClick(button: .right)
    }
    
    private func injectClick(button: CGMouseButton) {
        let position = clickPositions[button] ?? getCurrentCursorPosition()
        
        let isDoubleClick = checkDoubleClick(at: position)
        let clickState: Int = isDoubleClick ? 2 : 1
        
        print("[ClickInjector] Injecting \(button == .left ? "LEFT" : "RIGHT") click at \(position), clickState: \(clickState)")
        
        let mouseTypeDown = button == .left ? CGEventType.leftMouseDown : CGEventType.rightMouseDown
        let mouseTypeUp = button == .left ? CGEventType.leftMouseUp : CGEventType.rightMouseUp
        
        guard let mouseDown = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: mouseTypeDown,
            mouseCursorPosition: position,
            mouseButton: button
        ) else {
            print("[ClickInjector] Failed to create mouseDown event")
            return
        }
        
        mouseDown.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
        
        guard let mouseUp = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: mouseTypeUp,
            mouseCursorPosition: position,
            mouseButton: button
        ) else {
            print("[ClickInjector] Failed to create mouseUp event")
            return
        }
        
        mouseUp.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
        
        mouseDown.post(tap: CGEventTapLocation(rawValue: 1)!)
        mouseUp.post(tap: CGEventTapLocation(rawValue: 1)!)
        
        lastClickTime = CACurrentMediaTime()
        lastClickPosition = position
        
        print("[ClickInjector] Click posted successfully")
    }
    
    private func checkDoubleClick(at position: CGPoint) -> Bool {
        let now = CACurrentMediaTime()
        let timeSinceLastClick = now - lastClickTime
        
        let dx = position.x - lastClickPosition.x
        let dy = position.y - lastClickPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        
        let isDoubleClick = timeSinceLastClick < doubleClickTime && distance < doubleClickDistance
        
        print("[ClickInjector] Double-click check: time=\(String(format: "%.3f", timeSinceLastClick))s, dist=\(String(format: "%.1f", distance)), isDouble=\(isDoubleClick)")
        
        return isDoubleClick
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
        clickPositions.removeAll()
        lastClickTime = 0
        lastClickPosition = .zero
    }
}
