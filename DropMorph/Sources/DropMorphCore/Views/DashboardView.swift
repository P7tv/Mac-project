import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: ConversionViewModel

    public init(viewModel: ConversionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Navigation & Header Bar
            HStack(spacing: 12) {
                // App Logo and Name
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("DropMorph")
                            .font(.system(size: 15, weight: .bold))
                        Text("Fast Media Converter")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Space Saved Stats Badge
                if let savings = viewModel.overallSavingsPercentage, savings > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("Saved \(ByteCountFormatter.string(fromByteCount: viewModel.totalSavedBytes, countStyle: .file)) (\(savings)%)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
                    .foregroundColor(.green)
                }

                // Always On Top Pin Button
                Button {
                    viewModel.toggleAlwaysOnTop()
                } label: {
                    Image(systemName: viewModel.isPinnedOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(viewModel.isPinnedOnTop ? .white : .secondary)
                        .padding(7)
                        .background(
                            Circle()
                                .fill(viewModel.isPinnedOnTop ? Color.blue : Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help(viewModel.isPinnedOnTop ? "Always on Top: Active" : "Pin Window on Top")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Main Content Area
            VStack(spacing: 12) {
                if viewModel.queue.isEmpty {
                    // Empty State: Large Drop Zone
                    DropZoneView(viewModel: viewModel)
                        .padding(18)
                } else {
                    // Active Queue: Compact Drop Target + List
                    VStack(spacing: 10) {
                        // Compact drop hint
                        HStack {
                            Text("Queue (\(viewModel.queue.count) files)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("Clear All") {
                                withAnimation {
                                    viewModel.clearQueue()
                                }
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                        // Queue items list
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.queue) { item in
                                    QueueItemRowView(
                                        item: item,
                                        onRemove: {
                                            withAnimation {
                                                viewModel.removeItem(id: item.id)
                                            }
                                        },
                                        onReveal: {
                                            if let url = item.outputURL {
                                                viewModel.revealInFinder(url: url)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 18)
                        }

                        // Compact secondary drop area
                        DropZoneView(viewModel: viewModel)
                            .frame(height: 70)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom Settings Bar & Action Buttons
            VStack(spacing: 10) {
                SettingsBarView(viewModel: viewModel)

                HStack {
                    if let alert = viewModel.alertMessage {
                        Text(alert)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }

                    Spacer()

                    if viewModel.settings.targetFormat == .pdf && viewModel.queue.count > 1 {
                        Button {
                            Task {
                                await viewModel.processPDFMerge(items: viewModel.queue)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc.fill")
                                Text("Merge All into Single PDF")
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }

                    Button {
                        Task {
                            await viewModel.processQueue()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Converting...")
                            } else {
                                Image(systemName: "play.fill")
                                Text("Convert All")
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(viewModel.isProcessing || viewModel.queue.isEmpty)
                }
            }
            .padding(14)
            .background(Color.primary.opacity(0.02))
        }
        .background(.ultraThinMaterial)
        .frame(minWidth: 540, minHeight: 520)
    }
}
