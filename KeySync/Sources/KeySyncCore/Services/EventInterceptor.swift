import Foundation
import CoreGraphics
import AppKit

public final class EventInterceptor: @unchecked Sendable {
    public private(set) var isControllingRemote: Bool = false
    public var edgeDetector: EdgeDetector
    public var targetScreenBounds: CGRect
    public var canControlRemote: Bool = true
    public var remoteScreenSize: CGSize = CGSize(width: 1920, height: 1080)

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastLocalPoint: CGPoint = .zero
    private var lockedEdgePoint: CGPoint = .zero
    private var virtualRemoteX: CGFloat = 0.0
    private var virtualRemoteY: CGFloat = 0.0
    private let lock = NSLock()

    public var onControlStateChanged: (@Sendable (Bool) -> Void)?
    public var onEventIntercepted: (@Sendable (InputEvent) -> Void)?
    public var onLastEventDescription: (@Sendable (String) -> Void)?

    public init(
        edge: ScreenEdge = .right,
        screenBounds: CGRect = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    ) {
        self.edgeDetector = EdgeDetector(edge: edge)
        self.targetScreenBounds = screenBounds
    }

    public func updateEdge(_ edge: ScreenEdge) {
        lock.lock()
        defer { lock.unlock() }
        self.edgeDetector = EdgeDetector(edge: edge)
    }

    public func updateScreenBounds(_ bounds: CGRect) {
        lock.lock()
        defer { lock.unlock() }
        self.targetScreenBounds = bounds
    }

    public func start() {
        stop()

        guard AXIsProcessTrusted() else {
            print("[EventInterceptor] Accessibility permission not granted. Running in monitor mode.")
            return
        }

        let eventMask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let observer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let interceptor = Unmanaged<EventInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return interceptor.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            print("[EventInterceptor] Failed to create CGEventTap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                runLoopSource = nil
            }
            eventTap = nil
        }
        setControllingRemote(false)
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        lock.lock()
        let controlling = isControllingRemote
        let canControl = canControlRemote
        lock.unlock()

        // 1. Not currently controlling Windows PC: listen for edge collision
        if !controlling {
            if type == .mouseMoved {
                let location = event.location
                if edgeDetector.hasHitEdge(point: location, in: targetScreenBounds) && canControl {
                    lock.lock()
                    self.lockedEdgePoint = location
                    self.lastLocalPoint = location
                    switch edgeDetector.edge {
                    case .right:
                        virtualRemoteX = 0
                        virtualRemoteY = location.y
                    case .left:
                        virtualRemoteX = remoteScreenSize.width
                        virtualRemoteY = location.y
                    case .top:
                        virtualRemoteX = location.x
                        virtualRemoteY = remoteScreenSize.height
                    case .bottom:
                        virtualRemoteX = location.x
                        virtualRemoteY = 0
                    }
                    lock.unlock()
                    setControllingRemote(true)
                    CGWarpMouseCursorPosition(location)
                    onLastEventDescription?("Glided to Windows PC")
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }

        // 2. Currently controlling Windows PC: intercept & suppress
        // Emergency Escape (Esc keycode 53)
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == 53 { // ESC
                triggerPanicRelease()
                onLastEventDescription?("Emergency Escape to Mac")
                return nil
            }
        }

        // Mouse movement
        if type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged {
            let location = event.location
            lock.lock()
            let lastPoint = lastLocalPoint
            let lockedPoint = lockedEdgePoint
            lastLocalPoint = location

            let dx = Double(event.getDoubleValueField(.mouseEventDeltaX))
            let dy = Double(event.getDoubleValueField(.mouseEventDeltaY))

            let finalDx = (dx != 0) ? dx : Double(location.x - lastPoint.x)
            let finalDy = (dy != 0) ? dy : Double(location.y - lastPoint.y)

            virtualRemoteX += finalDx
            virtualRemoteY += finalDy

            // Check if user has intentionally pushed across the remote boundary to return to Mac
            var shouldReturn = false
            switch edgeDetector.edge {
            case .right:
                // User pushed left past the left edge of Windows screen
                if virtualRemoteX < -15.0 {
                    shouldReturn = true
                } else {
                    virtualRemoteX = min(remoteScreenSize.width, max(0, virtualRemoteX))
                }
            case .left:
                // User pushed right past the right edge of Windows screen
                if virtualRemoteX > remoteScreenSize.width + 15.0 {
                    shouldReturn = true
                } else {
                    virtualRemoteX = min(remoteScreenSize.width, max(0, virtualRemoteX))
                }
            case .top:
                // User pushed down past bottom of Windows screen
                if virtualRemoteY > remoteScreenSize.height + 15.0 {
                    shouldReturn = true
                } else {
                    virtualRemoteY = min(remoteScreenSize.height, max(0, virtualRemoteY))
                }
            case .bottom:
                // User pushed up past top of Windows screen
                if virtualRemoteY < -15.0 {
                    shouldReturn = true
                } else {
                    virtualRemoteY = min(remoteScreenSize.height, max(0, virtualRemoteY))
                }
            }

            if shouldReturn {
                lock.unlock()
                setControllingRemote(false)
                let returnPoint = calculateReturnPoint(from: lockedPoint)
                CGWarpMouseCursorPosition(returnPoint)
                onLastEventDescription?("Returned to Mac")
                return nil
            }

            lock.unlock()

            if abs(finalDx) > 0.1 || abs(finalDy) > 0.1 {
                let inputEvent = InputEvent.move(dx: finalDx, dy: finalDy)
                onEventIntercepted?(inputEvent)
                onLastEventDescription?("Mouse Move (\(Int(finalDx)), \(Int(finalDy)))")
            }

            CGWarpMouseCursorPosition(lockedPoint)
            return nil
        }

        // Mouse clicks
        if type == .leftMouseDown {
            onEventIntercepted?(InputEvent.click(button: 0, isDown: true))
            onLastEventDescription?("🖱️ Left Click Down")
            return nil
        }
        if type == .leftMouseUp {
            onEventIntercepted?(InputEvent.click(button: 0, isDown: false))
            onLastEventDescription?("🖱️ Left Click Up")
            return nil
        }
        if type == .rightMouseDown {
            onEventIntercepted?(InputEvent.click(button: 1, isDown: true))
            onLastEventDescription?("🖱️ Right Click Down")
            return nil
        }
        if type == .rightMouseUp {
            onEventIntercepted?(InputEvent.click(button: 1, isDown: false))
            onLastEventDescription?("🖱️ Right Click Up")
            return nil
        }
        if type == .otherMouseDown {
            onEventIntercepted?(InputEvent.click(button: 2, isDown: true))
            onLastEventDescription?("🖱️ Middle Click Down")
            return nil
        }
        if type == .otherMouseUp {
            onEventIntercepted?(InputEvent.click(button: 2, isDown: false))
            onLastEventDescription?("🖱️ Middle Click Up")
            return nil
        }

        // Scroll wheel
        if type == .scrollWheel {
            let deltaY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            let deltaX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            onEventIntercepted?(InputEvent.scroll(dx: deltaX, dy: deltaY))
            onLastEventDescription?("📜 Scroll (\(Int(deltaY)))")
            return nil
        }

        // Keyboard
        if type == .keyDown {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = UInt32(event.flags.rawValue)
            onEventIntercepted?(InputEvent.key(keyCode: keyCode, modifiers: flags, isDown: true))
            onLastEventDescription?("⌨️ Key Down: \(keyCode)")
            return nil
        }
        if type == .keyUp {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = UInt32(event.flags.rawValue)
            onEventIntercepted?(InputEvent.key(keyCode: keyCode, modifiers: flags, isDown: false))
            onLastEventDescription?("⌨️ Key Up: \(keyCode)")
            return nil
        }
        if type == .flagsChanged {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = UInt32(event.flags.rawValue)
            onEventIntercepted?(InputEvent.key(keyCode: keyCode, modifiers: flags, isDown: true))
            return nil
        }

        return nil
    }

    private func calculateReturnPoint(from location: CGPoint) -> CGPoint {
        var pt = location
        switch edgeDetector.edge {
        case .right: pt.x = max(10, targetScreenBounds.maxX - 40)
        case .left: pt.x = min(targetScreenBounds.maxX - 10, targetScreenBounds.minX + 40)
        case .top: pt.y = min(targetScreenBounds.maxY - 10, targetScreenBounds.minY + 40)
        case .bottom: pt.y = max(10, targetScreenBounds.maxY - 40)
        }
        return pt
    }

    public func handleMouseMoved(to currentPoint: CGPoint) {
        lock.lock()
        let controlling = isControllingRemote
        let lastPoint = lastLocalPoint
        lastLocalPoint = currentPoint

        if !controlling {
            if edgeDetector.hasHitEdge(point: currentPoint, in: targetScreenBounds) && canControlRemote {
                switch edgeDetector.edge {
                case .right:
                    virtualRemoteX = 0
                    virtualRemoteY = currentPoint.y
                case .left:
                    virtualRemoteX = remoteScreenSize.width
                    virtualRemoteY = currentPoint.y
                case .top:
                    virtualRemoteX = currentPoint.x
                    virtualRemoteY = remoteScreenSize.height
                case .bottom:
                    virtualRemoteX = currentPoint.x
                    virtualRemoteY = 0
                }
                lock.unlock()
                setControllingRemote(true)
                return
            }
            lock.unlock()
        } else {
            let dx = currentPoint.x - lastPoint.x
            let dy = currentPoint.y - lastPoint.y
            virtualRemoteX += dx
            virtualRemoteY += dy

            var shouldReturn = false
            switch edgeDetector.edge {
            case .right:
                if virtualRemoteX < -15.0 { shouldReturn = true }
                else { virtualRemoteX = min(remoteScreenSize.width, max(0, virtualRemoteX)) }
            case .left:
                if virtualRemoteX > remoteScreenSize.width + 15.0 { shouldReturn = true }
                else { virtualRemoteX = min(remoteScreenSize.width, max(0, virtualRemoteX)) }
            case .top:
                if virtualRemoteY > remoteScreenSize.height + 15.0 { shouldReturn = true }
                else { virtualRemoteY = min(remoteScreenSize.height, max(0, virtualRemoteY)) }
            case .bottom:
                if virtualRemoteY < -15.0 { shouldReturn = true }
                else { virtualRemoteY = min(remoteScreenSize.height, max(0, virtualRemoteY)) }
            }

            if shouldReturn {
                lock.unlock()
                setControllingRemote(false)
                return
            }
            lock.unlock()

            if abs(dx) > 0.1 || abs(dy) > 0.1 {
                onEventIntercepted?(InputEvent.move(dx: dx, dy: dy))
            }
        }
    }

    public func setControllingRemote(_ active: Bool) {
        lock.lock()
        guard isControllingRemote != active else {
            lock.unlock()
            return
        }
        isControllingRemote = active
        lock.unlock()

        onControlStateChanged?(active)
    }

    public func triggerPanicRelease() {
        setControllingRemote(false)
    }
}
