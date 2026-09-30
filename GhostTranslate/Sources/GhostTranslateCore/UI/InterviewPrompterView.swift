import SwiftUI

@MainActor
public struct InterviewPrompterView: View {
    @ObservedObject var appState: AppState
    
    public init(appState: AppState = .shared) {
        self.appState = appState
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundColor(.cyan)
                    .font(.system(size: 15))
                
                Text("Interview Co-pilot")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if appState.aiStatus == .translating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Thinking...")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                    }
                } else if appState.latencyMs > 0 {
                    Text("\(appState.latencyMs)ms")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                // Mic button
                Button(action: {
                    appState.audioEngine.toggleTranscription()
                }) {
                    Image(systemName: appState.audioEngine.isRecording ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(appState.audioEngine.isRecording ? .red : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Section 1: Detected Question
            VStack(alignment: .leading, spacing: 4) {
                Text("INTERVIEWER QUESTION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.8))
                
                Text(appState.originalText.isEmpty ? "Waiting for interviewer to speak..." : appState.originalText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(appState.originalText.isEmpty ? 0.4 : 0.9))
                    .lineLimit(2)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.08))
            .cornerRadius(8)
            
            // Section 2: Question Thai Summary
            if let result = appState.interviewResult, !result.questionSummary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("สรุปคำถาม (ใจความสำคัญ)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                    
                    Text(result.questionSummary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(8)
            }
            
            // Section 3: Recommended Talking Points (3 Bullets)
            VStack(alignment: .leading, spacing: 6) {
                Text("RECOMMENDED TALKING POINTS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
                
                if let result = appState.interviewResult, !result.bulletPoints.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(result.bulletPoints.enumerated()), id: \.offset) { index, bullet in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)
                                        .frame(width: 18, height: 18)
                                        .background(Color.green.opacity(0.9))
                                        .clipShape(Circle())
                                    
                                    Text(bullet)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.95))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("Talking points and answer guidance will appear automatically as the interviewer asks questions.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            
            Spacer(minLength: 0)
            
            // Footer with Clear / Re-run
            HStack {
                Button(action: {
                    appState.clear()
                }) {
                    Label("Clear", systemImage: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if !appState.originalText.isEmpty {
                    Button(action: {
                        Task { await appState.performTranslation(for: appState.originalText) }
                    }) {
                        Label("Re-analyze", systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green.opacity(0.4), Color.cyan.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}
