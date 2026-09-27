import SwiftUI
import RarPeekCore

@main
struct RarPeekApp: App {
    var body: some Scene {
        WindowGroup {
            Text("RarPeek \(RarPeekCore.version)")
                .frame(width: 400, height: 300)
        }
    }
}
