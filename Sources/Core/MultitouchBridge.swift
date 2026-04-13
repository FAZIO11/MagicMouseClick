import Foundation
import AppKit

enum DeviceType: Int {
    case unknown = 0
    case trackpad = 1
    case magicMouse = 2
    case magicTrackpad = 3
}

enum GestureEvent {
    case leftClick
    case rightClick
    case touchStart
    case touchEnd
    case unknown
    
    var description: String {
        switch self {
        case .leftClick: return "Tap → Left Click"
        case .rightClick: return "Tap → Right Click"
        case .touchStart: return "Touch Start"
        case .touchEnd: return "Touch End"
        case .unknown: return "Unknown"
        }
    }
}

struct TouchData {
    let position: CGPoint
    let fingerCount: Int
    let state: UInt32
    let timestamp: TimeInterval
}

protocol MultitouchBridgeDelegate: AnyObject {
    func multitouchBridge(_ bridge: MultitouchBridge, didReceiveTouches touches: [TouchData])
    func multitouchBridge(_ bridge: MultitouchBridge, didDetectGesture event: GestureEvent, fingerCount: Int)
}

final class MultitouchBridge {
    static let shared = MultitouchBridge()
    
    weak var delegate: MultitouchBridgeDelegate?
    
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var devices: [MTDeviceRef] = []
    private var isRunning = false
    
    private var touchSession: TouchSession?
    
    private let magicMouseFamilyID = 112
    
    private init() {}
    
    func start() {
        guard !isRunning else { return }
        
        frameworkHandle = dlopen(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
            RTLD_NOW
        )
        
        guard frameworkHandle != nil else {
            print("Failed to load MultitouchSupport framework")
            return
        }
        
        enumerateAndRegisterDevices()
        isRunning = true
    }
    
    func stop() {
        guard isRunning else { return }
        
        for device in devices {
            stopDevice(device)
        }
        devices.removeAll()
        
        if let handle = frameworkHandle {
            dlclose(handle)
            frameworkHandle = nil
        }
        
        isRunning = false
    }
    
    private func enumerateAndRegisterDevices() {
        guard let deviceList = MTDeviceCreateList() else { return }
        
        let count = CFArrayGetCount(deviceList)
        for i in 0..<count {
            guard let device = CFArrayGetValueAtIndex(deviceList, i) else { continue }
            let deviceRef = UnsafeMutableRawPointer(mutating: device)
            
            var familyID: Int32 = 0
            MTDeviceGetFamilyID(deviceRef, &familyID)
            
            if familyID == magicMouseFamilyID {
                registerCallback(for: deviceRef)
                startDevice(deviceRef)
                devices.append(deviceRef)
            }
        }
    }
    
    private func registerCallback(for device: MTDeviceRef) {
        let callback: MTFrameCallbackFunction = { device, touches, numTouches, timestamp, frame in
            self.handleTouchFrame(
                device: device,
                touches: touches,
                numTouches: numTouches,
                timestamp: timestamp,
                frame: frame
            )
            return 0
        }
        
        MTRegisterContactFrameCallback(device, callback)
    }
    
    private func startDevice(_ device: MTDeviceRef) {
        MTDeviceStart(device, 0)
    }
    
    private func stopDevice(_ device: MTDeviceRef) {
        MTDeviceStop(device)
    }
    
    private func handleTouchFrame(
        device: MTDeviceRef?,
        touches: UnsafePointer<MTTouch>?,
        numTouches: Int,
        timestamp: Double,
        frame: Int32
    ) {
        guard let touches = touches, numTouches > 0 else {
            if let session = touchSession, session.isActive {
                session.end(timestamp: timestamp)
                delegate?.multitouchBridge(self, didDetectGesture: .touchEnd, fingerCount: session.fingerCount)
            }
            touchSession = nil
            return
        }
        
        var touchDataArray: [TouchData] = []
        
        for i in 0..<numTouches {
            let touch = touches[i]
            
            let posX = CGFloat(touch.normalizedVector.position.x)
            let posY = CGFloat(touch.normalizedVector.position.y)
            
            let data = TouchData(
                position: CGPoint(x: posX, y: posY),
                fingerCount: numTouches,
                state: touch.state,
                timestamp: timestamp
            )
            touchDataArray.append(data)
            
            if touch.state == MTTouchStateMakeTouch {
                if touchSession == nil {
                    touchSession = TouchSession(fingerCount: numTouches, startTimestamp: timestamp)
                }
                delegate?.multitouchBridge(self, didDetectGesture: .touchStart, fingerCount: numTouches)
            }
            
            if touch.state == MTTouchStateBreakTouch {
                if let session = touchSession, session.isActive {
                    session.end(timestamp: timestamp)
                    
                    let duration = session.duration
                    if duration < SettingsManager.shared.tapDuration {
                        if session.fingerCount == 1 {
                            delegate?.multitouchBridge(self, didDetectGesture: .leftClick, fingerCount: 1)
                        } else if session.fingerCount == 2 {
                            delegate?.multitouchBridge(self, didDetectGesture: .rightClick, fingerCount: 2)
                        }
                    }
                }
                touchSession = nil
            }
        }
        
        delegate?.multitouchBridge(self, didReceiveTouches: touchDataArray)
    }
}

private class TouchSession {
    let fingerCount: Int
    let startTimestamp: TimeInterval
    private(set) var endTimestamp: TimeInterval?
    
    var isActive: Bool { endTimestamp == nil }
    var duration: TimeInterval { (endTimestamp ?? startTimestamp) - startTimestamp }
    
    init(fingerCount: Int, startTimestamp: TimeInterval) {
        self.fingerCount = fingerCount
        self.startTimestamp = startTimestamp
    }
    
    func end(timestamp: TimeInterval) {
        endTimestamp = timestamp
    }
}
