import SwiftUI
import AppKit
import DeskExtendCore

@main
struct DeskExtendApp: App {
    @StateObject private var viewModel = DeskExtendViewModel()
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
        .defaultSize(width: 550, height: 600)

        MenuBarExtra("DeskExtend", systemImage: viewModel.isStreaming ? "display.2" : "display") {
            VStack(alignment: .leading, spacing: 6) {
                Text("DeskExtend")
                    .font(.headline)

                Text(viewModel.isStreaming ? "Status: Streaming (\(viewModel.connectedClients) connected)" : "Status: Stopped")
                    .font(.caption)

                Divider()

                Button(viewModel.isStreaming ? "Stop Display" : "Start Display") {
                    viewModel.toggleStreaming()
                }
                .disabled(viewModel.isStarting)

                if let firstURL = viewModel.networkAddresses.first?.urlString {
                    Button("Copy URL: \(firstURL)") {
                        viewModel.copyURLToClipboard(url: firstURL)
                    }
                }

                Button("Open Dashboard Window") {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }

                Divider()

                Button("Quit DeskExtend") {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
