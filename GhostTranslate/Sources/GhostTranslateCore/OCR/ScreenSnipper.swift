import AppKit
import CoreGraphics

@MainActor
public final class ScreenSnipper: NSObject {
    public static let shared = ScreenSnipper()
    
    private var overlayWindows: [NSWindow] = []
    private var onComplete: ((CGImage?) -> Void)?
    
    public func startCapture(completion: @escaping (CGImage?) -> Void) {
        self.onComplete = completion
        
        // Remove any previous overlays
        closeOverlays()
        
        // Show an overlay window across all active screens
        for screen in NSScreen.screens {
            let overlay = SnipOverlayWindow(screen: screen) { [weak self] selectedRectInScreen in
                self?.closeOverlays()
                guard let rect = selectedRectInScreen, rect.width > 5, rect.height > 5 else {
                    completion(nil)
                    return
                }
                
                let image = self?.captureScreenRect(rect, screen: screen)
                completion(image)
            }
            overlayWindows.append(overlay)
            overlay.orderFrontRegardless()
        }
        
        NSCursor.crosshair.push()
    }
    
    private func closeOverlays() {
        NSCursor.pop()
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
    
    private func captureScreenRect(_ rect: NSRect, screen: NSScreen) -> CGImage? {
        // Convert screen coordinates to CGDisplay coordinates
        // macOS screen origin is bottom-left, CG coordinates origin is top-left of primary screen
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height
        
        let cgRect = CGRect(
            x: rect.origin.x,
            y: primaryHeight - (rect.origin.y + rect.height),
            width: rect.width,
            height: rect.height
        )
        
        return CGWindowListCreateImage(
            cgRect,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            [.nominalResolution, .bestResolution]
        )
    }
}

// Transparent overlay window for drawing selection rectangle
final class SnipOverlayWindow: NSWindow {
    private let onSelection: (NSRect?) -> Void
    
    init(screen: NSScreen, onSelection: @escaping (NSRect?) -> Void) {
        self.onSelection = onSelection
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.15)
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        
        let viewFrame = NSRect(origin: .zero, size: screen.frame.size)
        let snipView = SnipOverlayView(frame: viewFrame) { [weak self] rect in
            self?.onSelection(rect)
        }
        self.contentView = snipView
    }
    
    override var canBecomeKey: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onSelection(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

final class SnipOverlayView: NSView {
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private let onFinish: (NSRect?) -> Void
    
    init(frame: NSRect, onFinish: @escaping (NSRect?) -> Void) {
        self.onFinish = onFinish
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint, let end = currentPoint else {
            onFinish(nil)
            return
        }
        
        let rect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        // Convert view rect to screen rect
        let screenRect = window?.convertToScreen(rect) ?? rect
        onFinish(screenRect)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let start = startPoint, let end = currentPoint else { return }
        let selectionRect = NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        // Clear interior
        NSGraphicsContext.current?.cgContext.clear(selectionRect)
        
        // Draw neon bounding border
        let path = NSBezierPath(roundedRect: selectionRect, xRadius: 4, yRadius: 4)
        NSColor.systemCyan.setStroke()
        path.lineWidth = 2.0
        let dashes: [CGFloat] = [6.0, 3.0]
        path.setLineDash(dashes, count: 2, phase: 0)
        path.stroke()
    }
}
