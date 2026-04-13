import Foundation
import AppKit
import Darwin
import CoreGraphics

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
    let fingerID: Int32
    let fingerCount: Int
    let state: UInt32
    let timestamp: TimeInterval
    let size: Float
}

protocol MultitouchBridgeDelegate: AnyObject {
    func multitouchBridge(_ bridge: MultitouchBridge, didReceiveTouches touches: [TouchData])
    func multitouchBridge(_ bridge: MultitouchBridge, didDetectGesture event: GestureEvent, fingerCount: Int)
    func multitouchBridgeDidConnect(_ bridge: MultitouchBridge)
    func multitouchBridgeDidDisconnect(_ bridge: MultitouchBridge)
}

private var sharedBridge: MultitouchBridge?

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: UInt32
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector
    var zTotal: Float
    var field9: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector
    var field14: Int32
    var field15: Int32
    var zDensity: Float
}

let MTTouchStateNotTracking: UInt32 = 0
let MTTouchStateStartInRange: UInt32 = 1
let MTTouchStateHoverInRange: UInt32 = 2
let MTTouchStateMakeTouch: UInt32 = 3
let MTTouchStateTouching: UInt32 = 4
let MTTouchStateBreakTouch: UInt32 = 5
let MTTouchStateLingerInRange: UInt32 = 6
let MTTouchStateOutOfRange: UInt32 = 7

typealias MTDeviceCreateListFunc = @convention(c) () -> CFArray?
typealias MTDeviceGetFamilyIDFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>) -> Int32
typealias MTDeviceStartFunc = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
typealias MTDeviceStopFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
typealias MTRegisterCallbackFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void

private func touchCallback(
    _ device: UnsafeMutableRawPointer?,
    _ touches: UnsafeMutableRawPointer?,
    _ numTouches: Int32,
    _ timestamp: Double,
    _ frame: Int32,
    _ refcon: UnsafeMutableRawPointer?
) -> Int32 {
    guard let refcon = refcon, let touches = touches, let device = device else { return 0 }
    let bridge = Unmanaged<MultitouchBridge>.fromOpaque(refcon).takeUnretainedValue()
    let touchPtr = touches.withMemoryRebound(to: MTTouch.self, capacity: Int(numTouches)) { $0 }
    bridge.handleTouches(touchPtr, count: Int(numTouches), timestamp: timestamp, frame: frame)
    return 0
}

final class MultitouchBridge {
    static let shared = MultitouchBridge()
    
    weak var delegate: MultitouchBridgeDelegate?
    
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var devices: [UnsafeMutableRawPointer] = []
    private var isRunning = false
    private var isConnected = false
    
    private let gestureRecognizer = GestureRecognizer()
    
    private let stateQueue = DispatchQueue(label: "com.fazil.magicmouseclick.state")
    private var activeFingerIDs: Set<Int32> = []
    private var lastFrameCount = 0
    private var noTouchFrames = 0
    
    private let magicMouseFamilyID = 112
    private let magicMouseFamilyID2 = 113
    
    private init() {
        sharedBridge = self
        gestureRecognizer.delegate = self
    }
    
    func start() {
        print("[DEBUG] ========== MultitouchBridge.start() ==========")
        fflush(stdout)
        
        guard !isRunning else {
            print("[DEBUG] Already running")
            fflush(stdout)
            return
        }
        
        print("[DEBUG] Step 1: Permissions check")
        fflush(stdout)
        let accessibility = PermissionChecker.shared.hasAccessibilityPermission
        let inputMonitoring = PermissionChecker.shared.hasInputMonitoringPermission
        print("[DEBUG] Accessibility: \(accessibility), InputMonitoring: \(inputMonitoring)")
        fflush(stdout)
        
        print("[DEBUG] Step 2: Load framework")
        fflush(stdout)
        loadFramework()
        
        print("[DEBUG] Step 3: Enumerate devices")
        fflush(stdout)
        enumerateDevices()
        
        print("[DEBUG] Step 4: Done. isRunning=\(isRunning), isConnected=\(isConnected)")
        fflush(stdout)
    }
    
    func stop() {
        print("[DEBUG] stop() called")
        fflush(stdout)
        guard isRunning else { return }
        
        for device in devices {
            callDeviceStop(device)
        }
        devices.removeAll()
        
        if let handle = frameworkHandle {
            dlclose(handle)
            frameworkHandle = nil
        }
        
        isRunning = false
        isConnected = false
        sharedBridge = nil
    }
    
    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        
        print("[DEBUG] dlopen: \(path)")
        fflush(stdout)
        
        frameworkHandle = dlopen(path, RTLD_NOW)
        
        guard let handle = frameworkHandle else {
            let error = String(cString: dlerror())
            print("[DEBUG] dlopen FAILED: \(error)")
            fflush(stdout)
            return
        }
        
        print("[DEBUG] dlopen SUCCESS, handle=\(handle)")
        fflush(stdout)
        
        print("[DEBUG] All symbols resolved - checking MTDeviceCreateList...")
        fflush(stdout)
    }
    
    private func enumerateDevices() {
        guard let handle = frameworkHandle else {
            print("[DEBUG] No framework handle")
            fflush(stdout)
            return
        }
        
        guard let createListSym = dlsym(handle, "MTDeviceCreateList") else {
            print("[DEBUG] MTDeviceCreateList NOT FOUND")
            fflush(stdout)
            return
        }
        print("[DEBUG] MTDeviceCreateList symbol: \(createListSym)")
        fflush(stdout)
        
        let createList = unsafeBitCast(createListSym, to: MTDeviceCreateListFunc.self)
        print("[DEBUG] Calling MTDeviceCreateList()...")
        fflush(stdout)
        
        let deviceList = createList()
        
        guard let list = deviceList else {
            print("[DEBUG] MTDeviceCreateList() returned nil")
            print("[DEBUG] This means no multitouch devices are available to the system")
            fflush(stdout)
            return
        }
        
        let count = CFArrayGetCount(list)
        print("[DEBUG] MTDeviceCreateList() returned \(count) devices")
        fflush(stdout)
        
        guard let getFamilySym = dlsym(handle, "MTDeviceGetFamilyID") else {
            print("[DEBUG] MTDeviceGetFamilyID NOT FOUND")
            fflush(stdout)
            return
        }
        let getFamilyID = unsafeBitCast(getFamilySym, to: MTDeviceGetFamilyIDFunc.self)
        
        for i in 0..<count {
            guard let device = CFArrayGetValueAtIndex(list, i) else { continue }
            let deviceRef = UnsafeMutableRawPointer(mutating: device)
            
            var familyID: Int32 = 0
            _ = getFamilyID(deviceRef, &familyID)
            
            print("[DEBUG] Device \(i): familyID = \(familyID)")
            fflush(stdout)
            
            if familyID == magicMouseFamilyID || familyID == magicMouseFamilyID2 {
                print("[DEBUG] Found Magic Mouse! Registering...")
                fflush(stdout)
                registerCallback(for: deviceRef, handle: handle)
                startDevice(deviceRef)
                devices.append(deviceRef)
                isConnected = true
            }
        }
        
        if isConnected {
            delegate?.multitouchBridgeDidConnect(self)
            print("[DEBUG] CONNECTED to Magic Mouse!")
        } else {
            print("[DEBUG] No Magic Mouse found (looking for familyID \(magicMouseFamilyID) or \(magicMouseFamilyID2))")
        }
        fflush(stdout)
    }
    
    private func registerCallback(for device: UnsafeMutableRawPointer, handle: UnsafeMutableRawPointer) {
        guard let sym = dlsym(handle, "MTRegisterContactFrameCallbackWithRefcon") else {
            print("[DEBUG] MTRegisterContactFrameCallbackWithRefcon NOT FOUND")
            fflush(stdout)
            return
        }
        
        let registerFunc = unsafeBitCast(sym, to: MTRegisterCallbackFunc.self)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        let callbackPtr = unsafeBitCast(touchCallback as @convention(c) (
            UnsafeMutableRawPointer?,
            UnsafeMutableRawPointer?,
            Int32,
            Double,
            Int32,
            UnsafeMutableRawPointer?
        ) -> Int32, to: UnsafeMutableRawPointer.self)
        
        print("[DEBUG] Calling MTRegisterContactFrameCallbackWithRefcon...")
        fflush(stdout)
        registerFunc(device, callbackPtr, selfPtr)
        print("[DEBUG] Callback registered")
        fflush(stdout)
    }
    
    private func startDevice(_ device: UnsafeMutableRawPointer) {
        guard let handle = frameworkHandle,
              let sym = dlsym(handle, "MTDeviceStart") else {
            print("[DEBUG] MTDeviceStart NOT FOUND")
            fflush(stdout)
            return
        }
        
        let startFunc = unsafeBitCast(sym, to: MTDeviceStartFunc.self)
        let result = startFunc(device, 0)
        print("[DEBUG] MTDeviceStart result: \(result)")
        fflush(stdout)
    }
    
    private func callDeviceStop(_ device: UnsafeMutableRawPointer) {
        guard let handle = frameworkHandle,
              let sym = dlsym(handle, "MTDeviceStop") else {
            return
        }
        let stopFunc = unsafeBitCast(sym, to: MTDeviceStopFunc.self)
        _ = stopFunc(device)
    }
    
    func handleTouches(_ touches: UnsafePointer<MTTouch>, count: Int, timestamp: Double, frame: Int32) {
        print("[DEBUG] Received \(count) touches, frame=\(frame)")
        fflush(stdout)
        
        var activeTouches: [TouchData] = []
        var currentFingerIDs: Set<Int32> = []
        
        for i in 0..<count {
            let touch = touches[i]
            
            if touch.state == MTTouchStateMakeTouch {
                print("[DEBUG] *** STATE=3 (MakeTouch) fingerID=\(touch.fingerID) ***")
                fflush(stdout)
            } else if touch.state == MTTouchStateTouching {
                print("[DEBUG] *** STATE=4 (Touching) fingerID=\(touch.fingerID) ***")
                fflush(stdout)
            } else if touch.state == MTTouchStateBreakTouch {
                print("[DEBUG] *** STATE=5 (BreakTouch) fingerID=\(touch.fingerID) ***")
                fflush(stdout)
            }
            
            if touch.state == MTTouchStateMakeTouch || touch.state == MTTouchStateTouching {
                let posX = CGFloat(touch.normalizedVector.position.x)
                let posY = CGFloat(touch.normalizedVector.position.y)
                
                let data = TouchData(
                    position: CGPoint(x: posX, y: posY),
                    fingerID: touch.fingerID,
                    fingerCount: count,
                    state: touch.state,
                    timestamp: timestamp,
                    size: touch.zTotal
                )
                activeTouches.append(data)
                currentFingerIDs.insert(touch.fingerID)
                
                print("[DEBUG] Touch \(i): state=\(touch.state), fingerID=\(touch.fingerID), pos=(\(posX), \(posY))")
                fflush(stdout)
            }
        }
        
        var hadActiveFingers = false
        var currentNoTouchFrames = 0
        
        stateQueue.sync {
            hadActiveFingers = !activeFingerIDs.isEmpty
            activeFingerIDs = currentFingerIDs
            currentNoTouchFrames = noTouchFrames
        }
        
        if !activeTouches.isEmpty {
            let touchesCopy = activeTouches
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.gestureRecognizer.processTouches(touchesCopy)
                self.delegate?.multitouchBridge(self, didReceiveTouches: touchesCopy)
            }
            stateQueue.async { [weak self] in
                self?.noTouchFrames = 0
            }
        } else if hadActiveFingers {
            print("[DEBUG] Touch ended - notifying recognizer")
            fflush(stdout)
            stateQueue.async { [weak self] in
                self?.noTouchFrames += 1
                if self?.noTouchFrames ?? 0 >= 1 {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.gestureRecognizer.processTouches([])
                        self.delegate?.multitouchBridge(self, didReceiveTouches: [])
                    }
                    self?.activeFingerIDs.removeAll()
                }
            }
        } else {
            stateQueue.async { [weak self] in
                self?.noTouchFrames += 1
            }
        }
    }
}

extension MultitouchBridge: GestureRecognizerDelegate {
    func gestureRecognizer(_ recognizer: GestureRecognizer, didRecognizeTap fingerCount: Int, at position: CGPoint) {
        print("[DEBUG] TAP DETECTED: \(fingerCount) fingers at \(position)")
        fflush(stdout)
        let event: GestureEvent = fingerCount == 1 ? .leftClick : .rightClick
        delegate?.multitouchBridge(self, didDetectGesture: event, fingerCount: fingerCount)
    }
}
