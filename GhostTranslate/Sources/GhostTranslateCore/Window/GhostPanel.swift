import AppKit
import SwiftUI

/// A specialized NSPanel that is strictly excluded from macOS screen capture,
/// screen sharing (Zoom, Google Meet, Teams, Discord), and screen recordings
/// via `sharingType = .none`.
public final class GhostPanel: NSPanel {
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        
        setupStealthProperties()
    }
    
    private func setupStealthProperties() {
        // Critical: Invisibility to all ScreenCaptureKit / WindowServer capture
        self.sharingType = .none
        
        // Floating overlay level
        self.level = .floating
        
        // Visual styling: transparent backing, no window chrome
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        
        // Persist across Mission Control and full-screen apps
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        
        // Performance & responsiveness
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    /// Enable or disable mouse interaction pass-through.
    /// When true, clicks pass directly through to whatever is behind the HUD.
    public func setClickThrough(_ enabled: Bool) {
        self.ignoresMouseEvents = enabled
    }
    
    /// Adjust overall HUD alpha transparency
    public func setHUDAlpha(_ alpha: CGFloat) {
        self.alphaValue = min(max(alpha, 0.05), 1.0)
    }
}
