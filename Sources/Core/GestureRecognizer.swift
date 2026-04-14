import Foundation
import AppKit

protocol GestureRecognizerDelegate: AnyObject {
    func gestureRecognizer(_ recognizer: GestureRecognizer, didRecognizeTap fingerCount: Int, at position: CGPoint)
}

final class GestureRecognizer {
    weak var delegate: GestureRecognizerDelegate?
    
    private var activeSessions: [Int: SessionData] = [:]
    private var sessionTimer: Timer?
    private let tapTimeout: TimeInterval = 0.18
    
    private let maxDuration: TimeInterval = 0.18
    private let maxDisplacement: CGFloat = 0.04
    private let maxMovingFrames = 5
    
    private var lastTouchCount = 0
    
    func processTouches(_ touches: [TouchData]) {
        print("[GestureRecognizer] Processing \(touches.count) touches")
        
        for touch in touches {
            print("[GestureRecognizer]   fingerID: \(touch.fingerID), state: \(touch.state), pos: (\(touch.position.x), \(touch.position.y))")
        }
        
        if touches.isEmpty && lastTouchCount > 0 {
            print("[GestureRecognizer] Touch END detected")
            completePendingSession()
        }
        
        lastTouchCount = touches.count
        
        for touch in touches {
            if touch.state == MTTouchStateMakeTouch {
                print("[GestureRecognizer] *** STATE=3 (MakeTouch) ***")
                startSession(touch)
            } else if touch.state == MTTouchStateTouching {
                print("[GestureRecognizer] *** STATE=4 (Touching) ***")
                updateSession(touch)
            } else if touch.state == MTTouchStateBreakTouch {
                print("[GestureRecognizer] *** STATE=5 (BreakTouch) ***")
            }
        }
    }
    
    private func startSession(_ touch: TouchData) {
        let fingerID = Int(touch.fingerID)
        
        if activeSessions[fingerID] == nil {
            print("[GestureRecognizer] Starting NEW session for finger \(fingerID)")
            activeSessions[fingerID] = SessionData(
                fingerID: fingerID,
                startTime: CACurrentMediaTime(),
                startPosition: touch.position,
                lastPosition: touch.position,
                movingFrames: 0,
                isScroll: false
            )
            
            sessionTimer?.invalidate()
            sessionTimer = Timer.scheduledTimer(withTimeInterval: tapTimeout, repeats: false) { [weak self] _ in
                print("[GestureRecognizer] TIMER FIRED - completing pending session")
                self?.completePendingSession()
            }
        } else {
            print("[GestureRecognizer] Updating existing session for finger \(fingerID)")
            activeSessions[fingerID]?.lastPosition = touch.position
        }
    }
    
    private func updateSession(_ touch: TouchData) {
        let fingerID = Int(touch.fingerID)
        guard var session = activeSessions[fingerID] else { return }
        
        let dx = touch.position.x - session.lastPosition.x
        let dy = touch.position.y - session.lastPosition.y
        let frameMovement = sqrt(dx * dx + dy * dy)
        
        if frameMovement > 0.005 {
            session.movingFrames += 1
        }
        
        let totalDx = touch.position.x - session.startPosition.x
        let totalDy = touch.position.y - session.startPosition.y
        let displacement = sqrt(totalDx * totalDx + totalDy * totalDy)
        
        if displacement > maxDisplacement {
            session.isScroll = true
        }
        
        if session.movingFrames >= maxMovingFrames {
            session.isScroll = true
        }
        
        session.lastPosition = touch.position
        activeSessions[fingerID] = session
    }
    
    private func completePendingSession() {
        print("[GestureRecognizer] completePendingSession() called, sessions: \(activeSessions.count)")
        
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        guard !activeSessions.isEmpty else {
            print("[GestureRecognizer] No active sessions - returning")
            return
        }
        
        let fingerCount = activeSessions.count
        var avgPosition = CGPoint.zero
        var isScroll = false
        var duration: TimeInterval = 0
        var movingFrames = 0
        
        for (_, session) in activeSessions {
            avgPosition.x += session.startPosition.x
            avgPosition.y += session.startPosition.y
            isScroll = isScroll || session.isScroll
            duration = max(duration, CACurrentMediaTime() - session.startTime)
            movingFrames = max(movingFrames, session.movingFrames)
        }
        avgPosition.x /= CGFloat(fingerCount)
        avgPosition.y /= CGFloat(fingerCount)
        
        print("[GestureRecognizer] Session: \(fingerCount) fingers, duration: \(String(format: "%.3f", duration))s, movingFrames: \(movingFrames), isScroll: \(isScroll)")
        
        if isScroll {
            print("[GestureRecognizer] SCROLL - discarding")
        } else if duration >= maxDuration {
            print("[GestureRecognizer] Too slow - discarding (duration: \(String(format: "%.3f", duration))s >= \(maxDuration)s)")
        } else {
            print("[GestureRecognizer] TAP DETECTED!")
            injectClick(fingerCount: fingerCount, at: avgPosition)
        }
        
        activeSessions.removeAll()
    }
    
    private func injectClick(fingerCount: Int, at position: CGPoint) {
        print("[GestureRecognizer] INJECTING CLICK: \(fingerCount == 1 ? "LEFT" : "RIGHT")")
        
        guard SettingsManager.shared.gesturesEnabled else {
            print("[GestureRecognizer] Gestures disabled - skipping")
            return
        }

        if fingerCount == 1 {
            ClickInjector.shared.injectLeftClick()
        } else if fingerCount >= 2 {
            if SettingsManager.shared.rightClickEnabled {
                ClickInjector.shared.injectRightClick()
            }
        }
        
        delegate?.gestureRecognizer(self, didRecognizeTap: fingerCount, at: position)
    }
    
    func reset() {
        activeSessions.removeAll()
        sessionTimer?.invalidate()
        sessionTimer = nil
        lastTouchCount = 0
    }
}

private struct SessionData {
    let fingerID: Int
    let startTime: TimeInterval
    let startPosition: CGPoint
    var lastPosition: CGPoint
    var movingFrames: Int
    var isScroll: Bool
}
