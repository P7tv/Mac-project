import SwiftUI
import SweepSpaceCore

@main
struct SweepSpaceApp: App {
    var body: some Scene {
        WindowGroup {
            MainDashboardView()
                .frame(minWidth: 840, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
