import SwiftUI
import AppKit
import QuickRecallCore

@main
struct QuickRecallApp: App {
    @StateObject private var viewModel = QuickRecallViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            RecallMenuBarView(viewModel: viewModel) {
                appDelegate.showSearchWindow()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "brain.head.profile")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var searchPanel: NSPanel?
    var viewModel: QuickRecallViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Setup global hotkey (Cmd + Shift + Space)
        setupHotkey()
    }

    func showSearchWindow() {
        if searchPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 560),
                styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true

            let vm = self.viewModel ?? QuickRecallViewModel()
            self.viewModel = vm

            let hostingView = NSHostingView(rootView: RecallSearchView(viewModel: vm) { [weak panel] in
                panel?.orderOut(nil)
            })
            panel.contentView = hostingView
            self.searchPanel = panel
        }

        guard let panel = searchPanel else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func setupHotkey() {
        let spaceKeyCode: UInt16 = 49

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains([.command, .shift]) && event.keyCode == spaceKeyCode {
                Task { @MainActor [weak self] in
                    self?.showSearchWindow()
                }
            }
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains([.command, .shift]) && event.keyCode == spaceKeyCode {
                self.showSearchWindow()
                return nil
            }
            if event.keyCode == 53 { // ESC key
                if self.searchPanel?.isVisible == true {
                    self.searchPanel?.orderOut(nil)
                    return nil
                }
            }
            return event
        }
    }
}
