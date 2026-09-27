import SwiftUI

public struct ArchiveEntryRowView: View {
    let entry: ArchiveEntry
    let isSelected: Bool
    let onToggleSelect: () -> Void

    public init(entry: ArchiveEntry, isSelected: Bool, onToggleSelect: @escaping () -> Void) {
        self.entry = entry
        self.isSelected = isSelected
        self.onToggleSelect = onToggleSelect
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Checkbox for selection
            Button {
                onToggleSelect()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .blue : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)

            // File Icon
            Image(systemName: entry.iconSystemName)
                .font(.system(size: 15))
                .foregroundColor(entry.isDirectory ? .yellow : .blue)
                .frame(width: 20)

            // Filename and relative directory
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 13, weight: entry.isDirectory ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !entry.directoryPath.isEmpty {
                    Text(entry.directoryPath)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Encryption badge
            if entry.isEncrypted {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .help("Encrypted file")
            }

            // Uncompressed size
            if !entry.isDirectory {
                Text(entry.formattedSize)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 75, alignment: .trailing)
            } else {
                Text("Folder")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(width: 75, alignment: .trailing)
            }

            // Date
            if let date = entry.modificationDate {
                Text(date, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(width: 85, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleSelect()
        }
    }
}
