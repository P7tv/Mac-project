import SwiftUI
import AppKit
import DropMorphCore

@main
struct DropMorphApp: App {
    @StateObject private var viewModel = ConversionViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            DashboardView(viewModel: viewModel)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 580, height: 560)

        MenuBarExtra("DropMorph", systemImage: "arrow.triangle.2.circlepath.circle.fill") {
            MenuBarPopoverView(viewModel: viewModel) {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: "main")
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
