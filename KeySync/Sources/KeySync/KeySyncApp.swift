import SwiftUI
import AppKit
import KeySyncCore

@main
struct KeySyncApp: App {
    @StateObject private var viewModel = KeySyncViewModel()

    init() {
        NSApp.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("KeySync", id: "main") {
            DashboardView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 580, height: 680)

        MenuBarExtra {
            KeySyncMenuBarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: viewModel.isClientConnected ? "keyboard.fill" : "keyboard")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
