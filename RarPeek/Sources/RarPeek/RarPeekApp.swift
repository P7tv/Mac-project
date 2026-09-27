import SwiftUI
import RarPeekCore

@main
struct RarPeekApp: App {
    @StateObject private var viewModel = ArchiveViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 700, minHeight: 480)
                .onOpenURL { url in
                    Task {
                        await viewModel.loadArchive(url: url)
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Archive...") {
                    openFileDialog()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let selected = panel.url {
            Task {
                await viewModel.loadArchive(url: selected)
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ArchiveViewModel

    var body: some View {
        Group {
            if viewModel.currentArchive == nil {
                ArchiveDropZoneView(viewModel: viewModel)
            } else {
                ArchiveInspectorView(viewModel: viewModel)
            }
        }
        .alert(item: Binding<AlertItem?>(
            get: { viewModel.alertMessage.map { AlertItem(message: $0) } },
            set: { _ in viewModel.alertMessage = nil }
        )) { item in
            Alert(
                title: Text("RarPeek"),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
