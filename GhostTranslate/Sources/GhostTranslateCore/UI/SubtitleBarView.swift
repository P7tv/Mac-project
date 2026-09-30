import SwiftUI

@MainActor
public struct SubtitleBarView: View {
    @ObservedObject var appState: AppState
    
    public init(appState: AppState = .shared) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top Row: Status badge & original transcription
            HStack(spacing: 8) {
                // Mic recording pulse
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.audioEngine.isRecording ? Color.red : Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text(appState.audioEngine.isRecording ? "LIVE" : "PAUSED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(appState.audioEngine.isRecording ? .red : .gray)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
                
                // Original spoken speech
                if !appState.originalText.isEmpty {
                    Text(appState.originalText)
                        .font(.system(size: appState.subtitleFontSize * 0.85, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("Listening for speech or movie dialogue...")
                        .font(.system(size: appState.subtitleFontSize * 0.85, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                // Typhoon latency / status indicator
                if appState.aiStatus == .translating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Typhoon")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                } else if appState.latencyMs > 0 {
                    Text("\(appState.latencyMs)ms • Typhoon")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                }
            }
            
            // Bottom Row: Translated Thai Subtitle
            HStack(alignment: .center, spacing: 12) {
                if !appState.translatedText.isEmpty {
                    Text(appState.translatedText)
                        .font(.system(size: appState.subtitleFontSize + 3, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.98, blue: 1.0))
                        .shadow(color: Color.black.opacity(0.8), radius: 2, x: 0, y: 1)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("คำแปลภาษาไทยจะปรากฏที่นี่แบบเรียลไทม์...")
                        .font(.system(size: appState.subtitleFontSize, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
                
                Spacer()
                
                // Quick Action Buttons
                HStack(spacing: 6) {
                    if !appState.translatedText.isEmpty {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(appState.translatedText, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Copy Thai translation")
                    }
                    
                    Button(action: {
                        appState.audioEngine.toggleTranscription()
                    }) {
                        Image(systemName: appState.audioEngine.isRecording ? "mic.fill" : "mic.slash.fill")
                            .font(.system(size: 12))
                            .foregroundColor(appState.audioEngine.isRecording ? .red : .white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Microphone listening")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}
