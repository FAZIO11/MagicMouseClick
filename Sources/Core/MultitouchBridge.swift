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

final class MultitouchBridge {
    static let shared = MultitouchBridge()
    
    weak var delegate: MultitouchBridgeDelegate?
    
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var devices: [MTDeviceRef] = []
    private var isRunning = false
    private var isConnected = false
    
    private let gestureRecognizer = GestureRecognizer()
    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
    private let magicMouseFamilyID = 112
    private let palmRejection = PalmRejection()
    
    private init() {
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
        
        enumerateAndRegisterDevices()
        setupDeviceNotifications()
        isRunning = true
    }
    
    func stop() {
        guard isRunning else { return }
        
        teardownDeviceNotifications()
        
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
    
    private func enumerateAndRegisterDevices() {
        guard let deviceList = MTDeviceCreateList() else { return }
        
        let count = CFArrayGetCount(deviceList)
        var foundMagicMouse = false
        
        for i in 0..<count {
            guard let device = CFArrayGetValueAtIndex(deviceList, i) else { continue }
            let deviceRef = UnsafeMutableRawPointer(mutating: device)
            
            var familyID: Int32 = 0
            MTDeviceGetFamilyID(deviceRef, &familyID)
            
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
    
    private func registerCallback(for device: MTDeviceRef) {
        let callback: MTFrameCallbackFunction = { device, touches, numTouches, timestamp, frame in
            self.handleTouchFrame(
                device: device,
                touches: touches,
                numTouches: Int(numTouches),
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
            let emptyTouch = TouchData(
                position: .zero,
                fingerID: -1,
                fingerCount: 0,
                state: MTTouchStateNotTracking,
                timestamp: timestamp,
                size: 0
            )
            delegate?.multitouchBridge(self, didReceiveTouches: [emptyTouch])
            return
        }
        
        var touchDataArray: [TouchData] = []
        var activeTouches: [TouchData] = []
        
        for i in 0..<numTouches {
            let touch = touches[i]
            
            let posX = CGFloat(touch.normalizedVector.position.x)
            let posY = CGFloat(touch.normalizedVector.position.y)
            let position = CGPoint(x: posX, y: posY)
            
            let data = TouchData(
                position: position,
                fingerID: touch.fingerID,
                fingerCount: numTouches,
                state: touch.state,
                timestamp: timestamp,
                size: touch.zTotal
            )
            
            if palmRejection.shouldAccept(data: data) {
                touchDataArray.append(data)
                
                if touch.state == MTTouchStateMakeTouch || touch.state == MTTouchStateTouching {
                    activeTouches.append(data)
                }
            }
        }
        
        if !activeTouches.isEmpty {
            delegate?.multitouchBridge(self, didReceiveTouches: activeTouches)
            gestureRecognizer.processTouches(activeTouches)
        }
        
        for touch in touchDataArray {
            if touch.state == MTTouchStateMakeTouch {
                delegate?.multitouchBridge(self, didDetectGesture: .touchStart, fingerCount: numTouches)
            } else if touch.state == MTTouchStateBreakTouch {
                delegate?.multitouchBridge(self, didDetectGesture: .touchEnd, fingerCount: numTouches)
            }
        }
    }
    
    private func setupDeviceNotifications() {
        let matchingDict = IOServiceMatching("AppleMultitouchMouseDriver")
        
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        
        guard let notificationPort = notificationPort else { return }
        
        let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        let addCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon = refcon else { return }
            let bridge = Unmanaged<MultitouchBridge>.fromOpaque(refcon).takeUnretainedValue()
            bridge.handleDeviceAdded(iterator: iterator)
        }
        
        let removeCallback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon = refcon else { return }
            let bridge = Unmanaged<MultitouchBridge>.fromOpaque(refcon).takeUnretainedValue()
            bridge.handleDeviceRemoved(iterator: iterator)
        }
        
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            matchingDict,
            addCallback,
            selfPointer,
            &addedIterator
        )
        
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            matchingDict,
            removeCallback,
            selfPointer,
            &removedIterator
        )
        
        handleDeviceAdded(iterator: addedIterator)
        handleDeviceRemoved(iterator: removedIterator)
    }
    
    private func teardownDeviceNotifications() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        if let port = notificationPort {
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
    }
    
    private func handleDeviceAdded(iterator: io_iterator_t) {
        var service: io_object_t = 0
        repeat {
            service = IOIteratorNext(iterator)
            if service != 0 {
                IOObjectRelease(service)
            }
        } while service != 0
        
        DispatchQueue.main.async {
            if !self.isConnected {
                self.enumerateAndRegisterDevices()
            }
        }
    }
    
    private func handleDeviceRemoved(iterator: io_iterator_t) {
        var service: io_object_t = 0
        repeat {
            service = IOIteratorNext(iterator)
            if service != 0 {
                IOObjectRelease(service)
            }
        } while service != 0
        
        DispatchQueue.main.async {
            let hadConnection = self.isConnected
            self.enumerateAndRegisterDevices()
            
            if hadConnection && !self.isConnected {
                self.delegate?.multitouchBridgeDidDisconnect(self)
            }
        }
    }
}

extension MultitouchBridge: GestureRecognizerDelegate {
    func gestureRecognizer(_ recognizer: GestureRecognizer, didRecognizeTap fingerCount: Int, at position: CGPoint) {
        let event: GestureEvent = fingerCount == 1 ? .leftClick : .rightClick
        delegate?.multitouchBridge(self, didDetectGesture: event, fingerCount: fingerCount)
    }
}

private class PalmRejection {
    private let topEdgeThreshold: CGFloat = 0.25
    private let maxTouchSize: Float = 5.5
    
    func shouldAccept(data: TouchData) -> Bool {
        let pos = data.position
        
        if pos.y < topEdgeThreshold {
            return false
        }
        
        if data.size > maxTouchSize {
            return false
        }
        
        return true
    }
}
