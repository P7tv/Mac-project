import SwiftUI
import DeskExtendCore

@main
struct DeskExtendApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Welcome to \(DeskExtendInfo.appName)")
                .frame(width: 400, height: 300)
        }
    }
}
