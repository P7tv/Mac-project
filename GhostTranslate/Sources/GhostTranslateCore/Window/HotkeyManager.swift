import AppKit
import Carbon

@MainActor
public final class HotkeyManager {
    public static let shared = HotkeyManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    public init() {}
    
    public func startListening() {
        stopListening()
        
        let mask: NSEvent.EventTypeMask = .keyDown
        
        // Global monitor (when other apps like Zoom or Chrome are focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor (when GhostTranslate itself is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // consume event
            }
            return event
        }
    }
    
    public func stopListening() {
        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let isCmdOpt = flags == [.command, .option]
        
        guard isCmdOpt else { return false }
        
        switch event.keyCode {
        case 5: // 'G' key
            GhostWindowManager.shared.toggleVisibility()
            return true
            
        case 46: // 'M' key
            GhostWindowManager.shared.toggleMode()
            return true
            
        case 31: // 'O' key
            AppState.shared.triggerScreenOCR()
            return true
            
        case 8: // 'C' key
            GhostWindowManager.shared.toggleClickThrough()
            return true
            
        case 37: // 'L' key (Listen)
            AppState.shared.audioEngine.toggleTranscription()
            return true
            
        default:
            return false
        }
    }
}
