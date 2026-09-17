import SwiftUI
import AppKit
import AirBridgeCore

@main
struct AirBridgeApp: App {
    @StateObject private var viewModel = AirBridgeViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: viewModel.connectedClients > 0 ? "wave.3.forward.circle.fill" : "wave.3.forward.circle")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
