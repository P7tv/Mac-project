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
            // Header Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(.system(size: 15))

                    Text("DropMorph")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                Button {
                    onOpenMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Open Full Dashboard")
            }

            Divider()

            // Target Format Pills
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Target Format")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    if viewModel.settings.targetFormat == .webp ||
                       viewModel.settings.targetFormat == .jpeg ||
                       viewModel.settings.targetFormat == .heic {
                        Text("\(Int(round(viewModel.settings.quality * 100)))% Quality")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                }

                HStack(spacing: 5) {
                    ForEach([OutputFormat.webp, .jpeg, .png, .heic, .pdf]) { format in
                        let isSelected = viewModel.settings.targetFormat == format
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.settings.targetFormat = format
                            }
                        } label: {
                            Text(format.displayName)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(isSelected ? Color.blue : Color.primary.opacity(0.06))
                                )
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Compact Drop Zone (Guaranteed No Overlap!)
            DropZoneView(viewModel: viewModel, isCompact: true)

            // Queue Status / Recent Activity
            if !viewModel.queue.isEmpty {
                HStack(spacing: 6) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Converting \(viewModel.queue.count) files...")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        Text("\(viewModel.queue.count) files processed")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        if let saved = viewModel.overallSavingsPercentage, saved > 0 {
                            Text("(-\(saved)%)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            Divider()

            // Bottom Actions: Quit and Open Dashboard
            HStack {
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Spacer()

                Button {
                    onOpenMainWindow()
                } label: {
                    HStack(spacing: 4) {
                        Text("Open Dashboard")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 330)
        .background(.ultraThinMaterial)
    }
}
