import SwiftUI

@MainActor
public struct GhostHUDContainerView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var windowManager: GhostWindowManager
    
    @State private var isHovering = false
    
    public init(appState: AppState = .shared, windowManager: GhostWindowManager = .shared) {
        self.appState = appState
        self.windowManager = windowManager
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            // Drag handle and top stealth toolbar
            HStack(spacing: 8) {
                // Drag handle icon
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                
                // Stealth Invisibility indicator badge
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 9))
                    Text("GHOST MODE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(4)
                .help("Invisible to Zoom, Teams, Meet, Discord and Screen Recording")
                
                // Mode switcher
                Button(action: {
                    windowManager.toggleMode()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: windowManager.currentMode == .subtitleBar ? "rectangle.bottomthird.inset.filled" : "text.badge.star")
                            .font(.system(size: 10))
                        Text(windowManager.currentMode.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
                }
                // Automatic Language Status Badge
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                    Text("AUTO: EN ⟷ TH")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.35))
                .cornerRadius(4)
                .help("Automatically detects spoken language (English or Thai) and translates in real-time")
                
                Spacer()
                
                // Screen Snip OCR trigger
                Button(action: {
                    appState.triggerScreenOCR()
                }) {
                    Image(systemName: "crop")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Screen OCR Snip & Translate (⌥⌘O)")
                
                // Click-through toggle button
                Button(action: {
                    windowManager.toggleClickThrough()
                }) {
                    Image(systemName: windowManager.isClickThrough ? "cursorarrow.slash" : "cursorarrow")
                        .font(.system(size: 11))
                        .foregroundColor(windowManager.isClickThrough ? .yellow : .white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Toggle Click-Through Mode (⌥⌘C)")
                
                // Close / Hide button
                Button(action: {
                    windowManager.hide()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Hide Overlay (⌥⌘G)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.4))
            .cornerRadius(8)
            .opacity(isHovering || windowManager.currentMode == .interviewPrompter ? 1.0 : 0.4)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            
            // Main HUD View based on mode
            if windowManager.currentMode == .subtitleBar {
                SubtitleBarView(appState: appState)
            } else {
                InterviewPrompterView(appState: appState)
            }
        }
        .padding(6)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
