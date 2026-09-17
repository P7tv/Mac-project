import SwiftUI
import AppKit
import AudioTunnelCore

@main
struct AudioTunnelApp: App {
    @StateObject private var viewModel = AudioTunnelViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            DashboardView(viewModel: viewModel)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    viewModel.checkPermissions()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 580, height: 660)

        MenuBarExtra {
            AudioTunnelMenuBarView(viewModel: viewModel) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: viewModel.isStreaming ? "headphones.circle.fill" : "headphones")
                if viewModel.isStreaming && viewModel.connectedListeners > 0 {
                    Text("\(viewModel.connectedListeners)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
