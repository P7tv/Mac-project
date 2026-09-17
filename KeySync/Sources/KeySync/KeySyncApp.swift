import SwiftUI
import AppKit
import KeySyncCore

@main
struct KeySyncApp: App {
    @StateObject private var viewModel = KeySyncViewModel()

    var body: some Scene {
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
