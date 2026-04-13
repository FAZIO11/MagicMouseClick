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
    private var lastInjectedClickTime: TimeInterval = 0
    private let clickDebounceInterval: TimeInterval = 0.15
    
    private let movementThreshold: CGFloat = 0.04
    private let maxConsecutiveMovingFrames = 3
    
    private var lastTouchCount = 0
    
    func processTouches(_ touches: [TouchData]) {
        print("[GestureRecognizer] Processing \(touches.count) touches")
        
        for touch in touches {
            print("[GestureRecognizer]   fingerID: \(touch.fingerID), state: \(touch.state), pos: (\(touch.position.x), \(touch.position.y))")
        }
        
        if touches.isEmpty && lastTouchCount > 0 {
            print("[GestureRecognizer] Touch END detected - checking for tap")
            completePendingSession()
        }
        
        lastTouchCount = touches.count
        
        for touch in touches {
            if touch.state == MTTouchStateMakeTouch {
                print("[GestureRecognizer] *** STATE=3 (MakeTouch) for finger \(touch.fingerID) ***")
                startOrUpdateSession(touch)
            } else if touch.state == MTTouchStateTouching {
                print("[GestureRecognizer] *** STATE=4 (Touching) for finger \(touch.fingerID) ***")
                updateSessionWithMovement(touch)
            } else if touch.state == MTTouchStateBreakTouch {
                print("[GestureRecognizer] *** STATE=5 (BreakTouch) for finger \(touch.fingerID) ***")
                markSessionAsEnding(Int(touch.fingerID))
            }
            
            if touch.state == MTTouchStateMakeTouch || touch.state == MTTouchStateTouching {
                startOrUpdateSession(touch)
            }
        }
    }
    
    private func startOrUpdateSession(_ touch: TouchData) {
        let fingerID = Int(touch.fingerID)
        
        if activeSessions[fingerID] == nil {
            print("[GestureRecognizer] Starting session for finger \(fingerID)")
            activeSessions[fingerID] = SessionData(
                fingerID: fingerID,
                startTime: CACurrentMediaTime(),
                startPosition: touch.position,
                lastPosition: touch.position,
                maxDisplacement: 0,
                consecutiveMovingFrames: 0,
                isScroll: false
            )
            resetSessionTimer()
        } else {
            activeSessions[fingerID]?.lastPosition = touch.position
        }
    }
    
    private func updateSessionWithMovement(_ touch: TouchData) {
        let fingerID = Int(touch.fingerID)
        guard var session = activeSessions[fingerID] else { return }
        
        let dx = touch.position.x - session.lastPosition.x
        let dy = touch.position.y - session.lastPosition.y
        let frameDisplacement = sqrt(dx * dx + dy * dy)
        
        let totalDx = touch.position.x - session.startPosition.x
        let totalDy = touch.position.y - session.startPosition.y
        let totalDisplacement = sqrt(totalDx * totalDx + totalDy * totalDy)
        
        session.maxDisplacement = max(session.maxDisplacement, totalDisplacement)
        session.lastPosition = touch.position
        
        if frameDisplacement > movementThreshold {
            session.consecutiveMovingFrames += 1
            print("[GestureRecognizer] Frame displacement: \(frameDisplacement) - moving (frame \(session.consecutiveMovingFrames))")
        } else {
            session.consecutiveMovingFrames = 0
        }
        
        if session.consecutiveMovingFrames > maxConsecutiveMovingFrames {
            session.isScroll = true
            print("[GestureRecognizer] SCROLL DETECTED - too many consecutive moving frames")
        }
        
        activeSessions[fingerID] = session
    }
    
    private func markSessionAsEnding(_ fingerID: Int) {
        guard var session = activeSessions[fingerID] else { return }
        
        let dx = session.lastPosition.x - session.startPosition.x
        let dy = session.lastPosition.y - session.startPosition.y
        let totalDisplacement = sqrt(dx * dx + dy * dy)
        
        session.maxDisplacement = totalDisplacement
        
        if totalDisplacement > movementThreshold {
            session.isScroll = true
            print("[GestureRecognizer] SCROLL DETECTED - total displacement: \(totalDisplacement)")
        }
        
        activeSessions[fingerID] = session
    }
    
    private func resetSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: tapTimeout, repeats: false) { [weak self] _ in
            self?.completePendingSession()
        }
    }
    
    private func completePendingSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        guard !activeSessions.isEmpty else {
            print("[GestureRecognizer] No active sessions to complete")
            return
        }
        
        let fingerCount = activeSessions.count
        var avgPosition = CGPoint.zero
        
        var isScroll = false
        var maxDisplacement: CGFloat = 0
        var maxConsecutiveMoving = 0
        
        for (_, session) in activeSessions {
            avgPosition.x += session.startPosition.x
            avgPosition.y += session.startPosition.y
            isScroll = isScroll || session.isScroll
            maxDisplacement = max(maxDisplacement, session.maxDisplacement)
            maxConsecutiveMoving = max(maxConsecutiveMoving, session.consecutiveMovingFrames)
        }
        avgPosition.x /= CGFloat(fingerCount)
        avgPosition.y /= CGFloat(fingerCount)
        
        let duration = CACurrentMediaTime() - (activeSessions.values.first?.startTime ?? 0)
        
        print("[GestureRecognizer] Session complete: \(fingerCount) fingers, duration: \(duration)s, displacement: \(maxDisplacement)")
        
        if isScroll {
            print("[GestureRecognizer] SCROLL - no click fired")
        } else if duration >= tapTimeout {
            print("[GestureRecognizer] Too long - not a tap (duration: \(duration)s)")
        } else if maxConsecutiveMoving > maxConsecutiveMovingFrames {
            print("[GestureRecognizer] Scrolling motion - no click (consecutive moving frames: \(maxConsecutiveMoving))")
        } else if maxDisplacement > movementThreshold {
            print("[GestureRecognizer] Finger moved too much - not a tap (displacement: \(maxDisplacement))")
        } else {
            print("[GestureRecognizer] TAP DETECTED! \(fingerCount) fingers")
            injectClick(fingerCount: fingerCount, at: avgPosition)
        }
        
        activeSessions.removeAll()
    }
    
    private func injectClick(fingerCount: Int, at position: CGPoint) {
        let now = CACurrentMediaTime()
        
        if now - lastInjectedClickTime < clickDebounceInterval {
            print("[GestureRecognizer] Click debounced")
            return
        }
        
        lastInjectedClickTime = now
        
        print("[GestureRecognizer] INJECTING CLICK: \(fingerCount == 1 ? "LEFT" : "RIGHT")")
        
        if fingerCount == 1 {
            ClickInjector.shared.injectLeftClick()
        } else if fingerCount >= 2 {
            ClickInjector.shared.injectRightClick()
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
    var maxDisplacement: CGFloat
    var consecutiveMovingFrames: Int
    var isScroll: Bool
}
