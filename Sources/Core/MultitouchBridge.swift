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

private func touchCallback(
    device: UnsafeMutableRawPointer?,
    touches: UnsafeMutableRawPointer?,
    numTouches: Int32,
    timestamp: Double,
    frame: Int32,
    refcon: UnsafeMutableRawPointer?
) -> Int32 {
    guard let refcon = refcon else { return 0 }
    let bridge = Unmanaged<MultitouchBridge>.fromOpaque(refcon).takeUnretainedValue()
    
    let touchPtr = touches?.assumingMemoryBound(to: MTTouch.self)
    
    bridge.handleTouchFrame(
        device: device,
        touches: touchPtr,
        numTouches: Int(numTouches),
        timestamp: timestamp,
        frame: frame
    )
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
    
    private let magicMouseFamilyID = 112
    
    private var registerCallbackPtr: UnsafeMutableRawPointer?
    private var createListPtr: UnsafeMutableRawPointer?
    private var getFamilyIDPtr: UnsafeMutableRawPointer?
    private var deviceStartPtr: UnsafeMutableRawPointer?
    private var deviceStopPtr: UnsafeMutableRawPointer?
    
    private init() {
        sharedBridge = self
        gestureRecognizer.delegate = self
    }
    
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
        
        loadFunctionPointers()
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
        isConnected = false
    }
    
    private func loadFunctionPointers() {
        createListPtr = dlsym(frameworkHandle, "MTDeviceCreateList")
        getFamilyIDPtr = dlsym(frameworkHandle, "MTDeviceGetFamilyID")
        registerCallbackPtr = dlsym(frameworkHandle, "MTRegisterContactFrameCallbackWithRefcon")
        deviceStartPtr = dlsym(frameworkHandle, "MTDeviceStart")
        deviceStopPtr = dlsym(frameworkHandle, "MTDeviceStop")
    }
    
    private func enumerateAndRegisterDevices() {
        guard let ptr = createListPtr else { return }
        
        typealias CreateListFunc = @convention(c) () -> CFArray?
        let createList = unsafeBitCast(ptr, to: CreateListFunc.self)
        
        guard let deviceList = createList() else { return }
        
        let count = CFArrayGetCount(deviceList)
        var foundMagicMouse = false
        
        for i in 0..<count {
            guard let device = CFArrayGetValueAtIndex(deviceList, i) else { continue }
            let deviceRef = UnsafeMutableRawPointer(mutating: device)
            
            var familyID: Int32 = 0
            getFamilyID(device: deviceRef, familyID: &familyID)
            
            if familyID == magicMouseFamilyID {
                registerCallback(for: deviceRef)
                startDevice(deviceRef)
                devices.append(deviceRef)
                foundMagicMouse = true
            }
        }
        
        if foundMagicMouse && !isConnected {
            isConnected = true
            delegate?.multitouchBridgeDidConnect(self)
        }
    }
    
    private func getFamilyID(device: UnsafeMutableRawPointer, familyID: inout Int32) {
        guard let ptr = getFamilyIDPtr else { return }
        
        typealias GetFamilyIDFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>) -> Int32
        let funcPtr = unsafeBitCast(ptr, to: GetFamilyIDFunc.self)
        _ = funcPtr(device, &familyID)
    }
    
    private func registerCallback(for device: UnsafeMutableRawPointer) {
        guard let ptr = registerCallbackPtr else { return }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        typealias RegisterFunc = @convention(c) (
            UnsafeMutableRawPointer,
            @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32, UnsafeMutableRawPointer?) -> Int32,
            UnsafeMutableRawPointer
        ) -> Void
        
        let funcPtr = unsafeBitCast(ptr, to: RegisterFunc.self)
        funcPtr(device, touchCallback, selfPtr)
    }
    
    private func startDevice(_ device: UnsafeMutableRawPointer) {
        guard let ptr = deviceStartPtr else { return }
        
        typealias StartFunc = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
        let funcPtr = unsafeBitCast(ptr, to: StartFunc.self)
        _ = funcPtr(device, 0)
    }
    
    private func stopDevice(_ device: UnsafeMutableRawPointer) {
        guard let ptr = deviceStopPtr else { return }
        
        typealias StopFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
        let funcPtr = unsafeBitCast(ptr, to: StopFunc.self)
        _ = funcPtr(device)
    }
    
    func handleTouchFrame(
        device: UnsafeMutableRawPointer?,
        touches: UnsafePointer<MTTouch>?,
        numTouches: Int,
        timestamp: Double,
        frame: Int32
    ) {
        guard let touches = touches, numTouches > 0 else {
            DispatchQueue.main.async {
                let emptyTouch = TouchData(
                    position: .zero,
                    fingerID: -1,
                    fingerCount: 0,
                    state: MTTouchStateNotTracking,
                    timestamp: timestamp,
                    size: 0
                )
                self.delegate?.multitouchBridge(self, didReceiveTouches: [emptyTouch])
            }
            return
        }
        
        var activeTouches: [TouchData] = []
        
        for i in 0..<numTouches {
            let touch = touches[i]
            
            if touch.state != MTTouchStateMakeTouch && touch.state != MTTouchStateTouching {
                continue
            }
            
            if !shouldAcceptTouch(position: touch.normalizedVector, size: touch.zTotal) {
                continue
            }
            
            let posX = CGFloat(touch.normalizedVector.position.x)
            let posY = CGFloat(touch.normalizedVector.position.y)
            
            let data = TouchData(
                position: CGPoint(x: posX, y: posY),
                fingerID: touch.fingerID,
                fingerCount: numTouches,
                state: touch.state,
                timestamp: timestamp,
                size: touch.zTotal
            )
            activeTouches.append(data)
        }
        
        if !activeTouches.isEmpty {
            DispatchQueue.main.async {
                self.delegate?.multitouchBridge(self, didReceiveTouches: activeTouches)
                self.gestureRecognizer.processTouches(activeTouches)
            }
        }
    }
    
    private func shouldAcceptTouch(position: MTVector, size: Float) -> Bool {
        if position.position.y < 0.25 {
            return false
        }
        
        if size > 5.5 {
            return false
        }
        
        return true
    }
}

extension MultitouchBridge: GestureRecognizerDelegate {
    func gestureRecognizer(_ recognizer: GestureRecognizer, didRecognizeTap fingerCount: Int, at position: CGPoint) {
        let event: GestureEvent = fingerCount == 1 ? .leftClick : .rightClick
        delegate?.multitouchBridge(self, didDetectGesture: event, fingerCount: fingerCount)
    }
}

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
