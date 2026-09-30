import SwiftUI
import AppKit
import GhostTranslateCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        let hudView = GhostHUDContainerView(
            appState: AppState.shared,
            windowManager: GhostWindowManager.shared
        )
        GhostWindowManager.shared.setupPanel(with: hudView)
        HotkeyManager.shared.startListening()
        
        // Show Ghost HUD by default on launch
        GhostWindowManager.shared.show()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stopListening()
        AppState.shared.audioEngine.stopTranscription()
    }
}

@main
struct GhostTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var windowManager = GhostWindowManager.shared
    
    var body: some Scene {
        MenuBarExtra("GhostTranslate", systemImage: "eye.slash.fill") {
            VStack(alignment: .leading, spacing: 0) {
                Text("👻 GhostTranslate — Stealth Mode Active")
                    .font(.caption)
                    .bold()
                Text("Invisible to Zoom, Teams & Screen Share")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Button(windowManager.isVisible ? "Hide Ghost Overlay" : "Show Ghost Overlay") {
                    windowManager.toggleVisibility()
                }
                .keyboardShortcut("g", modifiers: [.command, .option])
                
                Button("Mode: \(windowManager.currentMode.rawValue) (Switch)") {
                    windowManager.toggleMode()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                
                Button("Screen OCR Snip & Translate") {
                    appState.triggerScreenOCR()
                }
                .keyboardShortcut("o", modifiers: [.command, .option])
                
                Button(windowManager.isClickThrough ? "Disable Click-Through" : "Enable Click-Through") {
                    windowManager.toggleClickThrough()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                
                Divider()
                
                Button(appState.audioEngine.isRecording ? "Pause Audio Listening (⌥⌘L)" : "Start Audio Listening (⌥⌘L)") {
                    appState.audioEngine.toggleTranscription()
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
                
                Button("Clear Subtitles") {
                    appState.clear()
                }
                
                Divider()
                
                Button("Quit GhostTranslate") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
        
        Settings {
            SettingsView(appState: appState, windowManager: windowManager)
        }
    }
}
