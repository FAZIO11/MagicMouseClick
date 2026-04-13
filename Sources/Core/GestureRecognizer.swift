import Foundation
import AppKit

protocol GestureRecognizerDelegate: AnyObject {
    func gestureRecognizer(_ recognizer: GestureRecognizer, didRecognizeTap fingerCount: Int, at position: CGPoint)
}

final class GestureRecognizer {
    weak var delegate: GestureRecognizerDelegate?
    
    private var sessions: [Int: GestureSession] = [:]
    private let palmRejection = PalmRejection()
    
    private var lastInjectedClickTime: TimeInterval = 0
    private let clickDebounceInterval: TimeInterval = 0.15
    
    func processTouches(_ touches: [TouchData]) {
        for touch in touches {
            switch touch.state {
            case MTTouchStateMakeTouch:
                startSession(for: touch)
            case MTTouchStateTouching:
                updateSession(for: touch)
            case MTTouchStateBreakTouch:
                endSession(for: touch)
            default:
                break
            }
        }
    }
    
    private func startSession(for touch: TouchData) {
        guard palmRejection.shouldAccept(touch: touch) else { return }
        
        let session = GestureSession(
            fingerID: Int(touch.fingerID),
            fingerCount: activeSessionCount() + 1,
            startTimestamp: touch.timestamp,
            startPosition: touch.position
        )
        sessions[Int(touch.fingerID)] = session
    }
    
    private func updateSession(for touch: TouchData) {
        guard var session = sessions[Int(touch.fingerID)] else { return }
        session.positions.append(touch.position)
        sessions[Int(touch.fingerID)] = session
    }
    
    private func endSession(for touch: TouchData) {
        guard var session = sessions[Int(touch.fingerID)] else { return }
        session.endTimestamp = touch.timestamp
        session.endPosition = touch.position
        
        let allSessions = sessions.values.filter { $0.fingerCount == session.fingerCount }
        let allEnded = allSessions.allSatisfy { $0.endTimestamp != nil }
        
        if allEnded {
            let totalFingers = allSessions.count
            let avgPosition = calculateAveragePosition(from: allSessions)
            
            if shouldRecognizeAsTap(sessions: Array(allSessions)) {
                injectClick(fingerCount: totalFingers, at: avgPosition)
            }
            
            sessions = sessions.filter { $0.value.endTimestamp == nil }
        }
    }
    
    private func activeSessionCount() -> Int {
        sessions.values.filter { $0.endTimestamp == nil }.count
    }
    
    private func calculateAveragePosition(from sessions: [GestureSession]) -> CGPoint {
        let positions = sessions.compactMap { $0.positions.first }
        guard !positions.isEmpty else { return .zero }
        
        let avgX = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count)
        let avgY = positions.reduce(0) { $0 + $1.y } / CGFloat(positions.count)
        
        return CGPoint(x: avgX, y: avgY)
    }
    
    private func shouldRecognizeAsTap(sessions: [GestureSession]) -> Bool {
        guard let firstSession = sessions.first else { return false }
        
        let duration = (firstSession.endTimestamp ?? firstSession.startTimestamp) - firstSession.startTimestamp
        guard duration < SettingsManager.shared.tapDuration else { return false }
        
        for session in sessions {
            let movement = session.totalMovement
            if movement > SettingsManager.shared.movementThreshold {
                return false
            }
        }
        
        return true
    }
    
    private func injectClick(fingerCount: Int, at position: CGPoint) {
        let now = CACurrentMediaTime()
        guard now - lastInjectedClickTime > clickDebounceInterval else { return }
        
        lastInjectedClickTime = now
        
        if fingerCount == 1 {
            ClickInjector.shared.injectLeftClick()
        } else if fingerCount == 2 {
            ClickInjector.shared.injectRightClick()
        }
        
        delegate?.gestureRecognizer(self, didRecognizeTap: fingerCount, at: position)
    }
    
    func reset() {
        sessions.removeAll()
    }
}

struct GestureSession {
    let fingerID: Int
    let fingerCount: Int
    let startTimestamp: TimeInterval
    let startPosition: CGPoint
    var positions: [CGPoint] = []
    var endTimestamp: TimeInterval?
    var endPosition: CGPoint?
    
    var duration: TimeInterval {
        (endTimestamp ?? startTimestamp) - startTimestamp
    }
    
    var totalMovement: CGFloat {
        var total: CGFloat = 0
        var previous = startPosition
        
        for position in positions {
            total += distance(from: previous, to: position)
            previous = position
        }
        
        if let end = endPosition {
            total += distance(from: previous, to: end)
        }
        
        return total
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
}

final class PalmRejection {
    private let topEdgeThreshold: CGFloat = 0.3
    private let bottomEdgeThreshold: CGFloat = 0.95
    private let sideEdgeThreshold: CGFloat = 0.02
    private let maxTouchSize: Float = 5.5
    
    func shouldAccept(touch: TouchData) -> Bool {
        let pos = touch.position
        
        if pos.y > topEdgeThreshold && pos.y < bottomEdgeThreshold {
            return true
        }
        
        if pos.x < sideEdgeThreshold || pos.x > (1.0 - sideEdgeThreshold) {
            return false
        }
        
        return true
    }
}
