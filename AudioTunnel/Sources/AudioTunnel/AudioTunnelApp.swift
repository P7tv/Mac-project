import SwiftUI
import AppKit
import AudioTunnelCore

@main
struct AudioTunnelApp: App {
    @StateObject private var viewModel = AudioTunnelViewModel()

    var body: some Scene {
        MenuBarExtra {
            AudioTunnelMenuBarView(viewModel: viewModel)
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
