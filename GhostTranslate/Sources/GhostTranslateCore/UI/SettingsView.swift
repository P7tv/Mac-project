import SwiftUI

@MainActor
public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var windowManager: GhostWindowManager
    
    @State private var apiKeyInput: String = ""
    @State private var showKey: Bool = false
    @State private var testResult: String?
    @State private var isTestingKey: Bool = false
    
    public init(appState: AppState = .shared, windowManager: GhostWindowManager = .shared) {
        self.appState = appState
        self.windowManager = windowManager
        _apiKeyInput = State(initialValue: appState.typhoonAPIKey)
    }
    
    public var body: some View {
        TabView {
            // Tab 1: Typhoon AI Settings
            Form {
                Section(header: Text("Typhoon AI Configuration").font(.headline)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key (SCB 10X OpenTyphoon)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if showKey {
                                TextField("sk-...", text: $apiKeyInput)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("sk-...", text: $apiKeyInput)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button(action: { showKey.toggle() }) {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack {
                            Button("Save Key") {
                                appState.typhoonAPIKey = apiKeyInput
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Test Connection") {
                                testTyphoonConnection()
                            }
                            .disabled(isTestingKey)
                            
                            if isTestingKey {
                                ProgressView().scaleEffect(0.6)
                            }
                            
                            if let result = testResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundColor(result.contains("Success") ? .green : .red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Picker("Model", selection: $appState.typhoonModel) {
                        Text("typhoon-v2.5-30b-a3b-instruct (Recommended)").tag("typhoon-v2.5-30b-a3b-instruct")
                        Text("typhoon-v1.5-instruct").tag("typhoon-v1.5-instruct")
                    }
                    
                    Slider(value: $appState.subtitleFontSize, in: 12...28, step: 1) {
                        Text("Subtitle Font Size: \(Int(appState.subtitleFontSize))pt")
                    }
                }
            }
            .tabItem {
                Label("Typhoon AI", systemImage: "sparkles")
            }
            .padding(20)
            
            // Tab 2: Audio & OCR
            Form {
                Section(header: Text("Audio & Speech Recognition").font(.headline)) {
                    Picker("Input Spoken Language", selection: Binding(
                        get: { appState.audioEngine.selectedLocale },
                        set: { appState.audioEngine.setLocale($0) }
                    )) {
                        Text("English (US)").tag(Locale(identifier: "en-US"))
                        Text("English (UK)").tag(Locale(identifier: "en-GB"))
                        Text("Thai (ภาษาไทย)").tag(Locale(identifier: "th-TH"))
                        Text("Japanese (日本語)").tag(Locale(identifier: "ja-JP"))
                        Text("Chinese (中文)").tag(Locale(identifier: "zh-CN"))
                    }
                    
                    HStack {
                        Text("Live Mic Status:")
                        Circle()
                            .fill(appState.audioEngine.isRecording ? Color.red : Color.gray)
                            .frame(width: 10, height: 10)
                        Text(appState.audioEngine.isRecording ? "Listening" : "Idle")
                            .font(.callout)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Permissions")
                            .font(.subheadline)
                            .bold()
                        
                        Button("Open Privacy & Security Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("Audio & OCR", systemImage: "waveform")
            }
            .padding(20)
            
            // Tab 3: Stealth & Shortcuts
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "eye.slash.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)
                    
                    VStack(alignment: .leading) {
                        Text("Stealth Architecture")
                            .font(.headline)
                        Text("GhostTranslate windows use NSWindow.sharingType = .none. The overlay is strictly hidden from Zoom, Microsoft Teams, Google Meet, Slack, Discord, and screen capture.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(10)
                
                Divider()
                
                Text("Global Hotkeys")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    HotkeyRow(keys: "⌥ ⌘ G", description: "Toggle Ghost Overlay (Show / Hide)")
                    HotkeyRow(keys: "⌥ ⌘ M", description: "Switch Mode (Subtitle Bar ↔ Interview Co-pilot)")
                    HotkeyRow(keys: "⌥ ⌘ O", description: "Screen OCR Snip & Translate")
                    HotkeyRow(keys: "⌥ ⌘ C", description: "Toggle Click-Through Mode")
                }
                
                Divider()
                
                Slider(value: $windowManager.opacity, in: 0.2...1.0, step: 0.05) {
                    Text("HUD Opacity: \(Int(windowManager.opacity * 100))%")
                }
                
                Spacer()
            }
            .tabItem {
                Label("Stealth & Hotkeys", systemImage: "keyboard")
            }
            .padding(20)
        }
        .frame(width: 520, height: 380)
    }
    
    private func testTyphoonConnection() {
        isTestingKey = true
        testResult = nil
        
        Task {
            let service = TyphoonService()
            await service.setAPIKey(apiKeyInput.isEmpty ? nil : apiKeyInput)
            await service.setModel(appState.typhoonModel)
            
            let start = DispatchTime.now()
            do {
                _ = try await service.translateSubtitle(text: "Hello, testing connection.")
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
                testResult = String(format: "Success! (%.0f ms)", elapsed)
            } catch {
                testResult = "Failed: \(error.localizedDescription)"
            }
            isTestingKey = false
        }
    }
}

struct HotkeyRow: View {
    let keys: String
    let description: String
    
    var body: some View {
        HStack {
            Text(keys)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            
            Text(description)
                .font(.system(size: 12))
            
            Spacer()
        }
    }
}
