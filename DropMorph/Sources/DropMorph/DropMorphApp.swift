import SwiftUI
import DropMorphCore

@main
struct DropMorphApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Welcome to \(DropMorphCoreInfo.appName)")
                .frame(width: 400, height: 300)
        }
    }
}
