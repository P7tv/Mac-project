import AppKit
import SwiftUI

public enum HUDMode: String, CaseIterable, Codable {
    case subtitleBar = "Subtitle Bar"
    case interviewPrompter = "Interview Co-pilot"
}

@MainActor
public final class GhostWindowManager: ObservableObject {
    public static let shared = GhostWindowManager()
    
    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var isClickThrough: Bool = false
    @Published public var currentMode: HUDMode = .subtitleBar {
        didSet {
            updateWindowGeometryForMode(currentMode)
        }
    }
    @Published public var opacity: Double = 0.85 {
        didSet {
            panel?.setHUDAlpha(CGFloat(opacity))
        }
    }
    
    public private(set) var panel: GhostPanel?
    
    public init() {
        // Will be configured when hosting view is attached
    }
    
// Custom NSHostingView that accepts mouse clicks even when the window is non-activating
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

    /// Attach the SwiftUI root view to the stealth GhostPanel
    public func setupPanel<Content: View>(with content: Content) {
        let initialRect = defaultRect(for: currentMode)
        let ghostPanel = GhostPanel(contentRect: initialRect)
        
        let hostingView = FirstMouseHostingView(rootView: content)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        
        ghostPanel.contentView = hostingView
        ghostPanel.setHUDAlpha(CGFloat(opacity))
        ghostPanel.setClickThrough(isClickThrough)
        
        self.panel = ghostPanel
    }
    
    public func toggleVisibility() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    public func show() {
        guard let panel = panel else { return }
        panel.orderFrontRegardless()
        isVisible = true
    }
    
    public func hide() {
        guard let panel = panel else { return }
        panel.orderOut(nil)
        isVisible = false
    }
    
    public func toggleClickThrough() {
        setClickThrough(!isClickThrough)
    }
    
    public func setClickThrough(_ enabled: Bool) {
        isClickThrough = enabled
        panel?.setClickThrough(enabled)
    }
    
    public func toggleMode() {
        currentMode = (currentMode == .subtitleBar) ? .interviewPrompter : .subtitleBar
    }
    
    public func updateWindowGeometryForMode(_ mode: HUDMode) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let targetRect = defaultRect(for: mode, on: screen)
        panel.setFrame(targetRect, display: true, animate: true)
    }
    
    private func defaultRect(for mode: HUDMode, on screen: NSScreen? = NSScreen.main) -> NSRect {
        let screenRect = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        switch mode {
        case .subtitleBar:
            let width: CGFloat = min(860, screenRect.width * 0.75)
            let height: CGFloat = 148
            let x = screenRect.origin.x + (screenRect.width - width) / 2.0
            let y = screenRect.origin.y + 60 // Floating above Dock / taskbar
            return NSRect(x: x, y: y, width: width, height: height)
            
        case .interviewPrompter:
            let width: CGFloat = 430
            let height: CGFloat = min(560, screenRect.height * 0.7)
            let x = screenRect.origin.x + screenRect.width - width - 30 // Top right near camera
            let y = screenRect.origin.y + screenRect.height - height - 40
            return NSRect(x: x, y: y, width: width, height: height)
        }
    }
}
