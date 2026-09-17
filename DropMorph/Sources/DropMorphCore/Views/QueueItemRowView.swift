import SwiftUI
import AppKit

public struct QueueItemRowView: View {
    @ObservedObject var item: ConversionItem
    var onRemove: () -> Void
    var onReveal: () -> Void

    public init(item: ConversionItem, onRemove: @escaping () -> Void, onReveal: @escaping () -> Void) {
        self.item = item
        self.onRemove = onRemove
        self.onReveal = onReveal
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Thumbnail preview
            Group {
                if let nsImage = NSImage(contentsOf: item.inputURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    let fileIcon = NSWorkspace.shared.icon(forFile: item.inputURL.path)
                    Image(nsImage: fileIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .padding(2)
                }
            }
            .frame(width: 44, height: 44)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalFilename)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(item.formattedOriginalSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if let converted = item.formattedConvertedSize {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)

                        Text(converted)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    if let savings = item.savingsPercentage {
                        Text(savings >= 0 ? "−\(savings)%" : "+\(abs(savings))%")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(savings > 0 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            )
                            .foregroundColor(savings > 0 ? .green : .orange)
                    }
                }
            }

            Spacer()

            // Status Indicator & Action Buttons
            HStack(spacing: 10) {
                switch item.status {
                case .pending:
                    Text("Pending")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))

                case .processing:
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Processing")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }

                case .completed:
                    Button {
                        onReveal()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                            Text("Reveal")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                case .failed(let error):
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .help(error)
                }

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(4)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
