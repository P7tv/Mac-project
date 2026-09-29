import SwiftUI

public struct DiskHeroCardView: View {
    @ObservedObject var viewModel: SweepSpaceViewModel

    public init(viewModel: SweepSpaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 28) {
            // Circular Disk Gauge
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 14)
                    .frame(width: 120, height: 120)

                // Used Space Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(viewModel.diskInfo.usedPercentage))
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.diskInfo.usedPercentage)

                // Recoverable overlay if scanned
                if viewModel.diskInfo.recoverablePercentage > 0.005 {
                    Circle()
                        .trim(
                            from: CGFloat(max(viewModel.diskInfo.usedPercentage - viewModel.diskInfo.recoverablePercentage, 0)),
                            to: CGFloat(viewModel.diskInfo.usedPercentage)
                        )
                        .stroke(
                            Color.green,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                }

                VStack(spacing: 2) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary.opacity(0.8))

                    Text("\(Int(viewModel.diskInfo.usedPercentage * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Used")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // Stats and Action Button
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mac Storage Overview")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            Text(viewModel.diskInfo.formattedFree)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Free of \(viewModel.diskInfo.formattedTotal)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Action Button
                    if viewModel.isScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Scanning...")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                    } else if viewModel.isCleaning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Cleaning...")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                    } else if viewModel.items.isEmpty {
                        Button {
                            viewModel.startScan()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Scan Storage")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 8) {
                            Button {
                                viewModel.startScan()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                    .padding(8)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Re-scan disk")

                            Button {
                                Task {
                                    await viewModel.cleanSelected(useTrash: true)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text("Clean Selected (\(viewModel.formattedSelectedBytes))")
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(
                                    viewModel.selectedBytes > 0
                                        ? LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.selectedBytes == 0)
                        }
                    }
                }

                // Recoverable Pill Stat
                if viewModel.totalRecoverableBytes > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))

                        Text("Recoverable: \(ByteCountFormatter.string(fromByteCount: viewModel.totalRecoverableBytes, countStyle: .file))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)

                        Text("•  \(viewModel.selectedItems.count) of \(viewModel.items.count) items selected")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
