import Foundation
import CoreGraphics
import DeskExtendBridge

public final class VirtualDisplayManager: @unchecked Sendable {
    private var virtualDisplay: DeskExtendVirtualDisplay?
    private let lock = NSLock()

    public init() {}

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return virtualDisplay?.isApplied ?? false
    }

    public var activeDisplayID: CGDirectDisplayID? {
        lock.lock()
        defer { lock.unlock() }
        guard let vd = virtualDisplay, vd.isApplied else { return nil }
        return vd.displayID
    }

    public func start(config: DisplayConfig) -> CGDirectDisplayID? {
        lock.lock()
        defer { lock.unlock() }

        // Stop any existing display
        virtualDisplay?.terminate()
        virtualDisplay = nil

        let vd = DeskExtendVirtualDisplay(
            width: config.resolution.width,
            height: config.resolution.height,
            refreshRate: config.refreshRate,
            hiDPI: config.hiDPI,
            name: config.displayName
        )

        guard let display = vd, display.isApplied else {
            return nil
        }

        self.virtualDisplay = display
        return display.displayID
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        virtualDisplay?.terminate()
        virtualDisplay = nil
    }

    deinit {
        stop()
    }
}
