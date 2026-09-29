import SwiftUI
import AppKit

public struct CleanableItemRowView: View {
    public let item: CleanableItem
    public let isSelected: Bool
    public let onToggle: () -> Void
    public let onReveal: () -> Void

    @State private var isHovered: Bool = false

    public init(
        item: CleanableItem,
        isSelected: Bool,
        onToggle: @escaping () -> Void,
        onReveal: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onReveal = onReveal
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? item.category.accentColor : .secondary.opacity(0.4))
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)

            Image(systemName: item.fileCount > 1 ? "folder.fill" : "doc.fill")
                .foregroundColor(item.category.accentColor.opacity(0.85))
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    if !item.isSafeToClean {
                        Text("USER FILE")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }

                Text(item.path.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isHovered {
                Button(action: onReveal) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }

            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(minWidth: 65, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
