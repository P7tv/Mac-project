import SwiftUI
import AppKit

public struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: ConversionViewModel
    var onOpenMainWindow: () -> Void

    public init(viewModel: ConversionViewModel, onOpenMainWindow: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onOpenMainWindow = onOpenMainWindow
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundColor(.blue)
                    Text("DropMorph")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Button {
                    onOpenMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Open Full Dashboard")
            }

            Divider()

            // Quick Format Switcher
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Format:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    ForEach([OutputFormat.webp, .jpeg, .png, .heic, .pdf]) { format in
                        let isSelected = viewModel.settings.targetFormat == format
                        Button {
                            viewModel.settings.targetFormat = format
                        } label: {
                            Text(format.displayName)
                                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isSelected ? Color.blue : Color.primary.opacity(0.06))
                                )
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Compact Drop Zone
            DropZoneView(viewModel: viewModel)
                .frame(height: 100)

            // Status & Quick Action
            HStack {
                if !viewModel.queue.isEmpty {
                    Text("\(viewModel.queue.count) files in queue")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Open Dashboard") {
                    onOpenMainWindow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
}
