import SwiftUI

public struct CategoryRowView: View {
    @ObservedObject var viewModel: SweepSpaceViewModel
    public let category: CleaningCategory
    @State private var isExpanded: Bool = true

    public init(viewModel: SweepSpaceViewModel, category: CleaningCategory) {
        self.viewModel = viewModel
        self.category = category
    }

    private var categoryItems: [CleanableItem] {
        viewModel.items(for: category)
    }

    private var totalBytes: Int64 {
        viewModel.categoryBytes(for: category)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 14)

                        ZStack {
                            Circle()
                                .fill(category.accentColor.opacity(0.15))
                                .frame(width: 32, height: 32)

                            Image(systemName: category.systemImage)
                                .foregroundColor(category.accentColor)
                                .font(.system(size: 14))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(category.rawValue)
                                    .font(.system(size: 13, weight: .bold))

                                Text("(\(categoryItems.count))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Text(category.subtitle)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Actions: Select All / Deselect
                if !categoryItems.isEmpty {
                    HStack(spacing: 6) {
                        Button("Select All") {
                            viewModel.selectAll(for: category)
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)

                        Text("•")
                            .foregroundColor(.secondary.opacity(0.4))

                        Button("Deselect") {
                            viewModel.deselectAll(for: category)
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }

                // Size Badge
                Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(totalBytes > 0 ? category.accentColor : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(category.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.025))

            // Expandable List of Items
            if isExpanded && !categoryItems.isEmpty {
                Divider()

                VStack(spacing: 1) {
                    ForEach(categoryItems) { item in
                        CleanableItemRowView(
                            item: item,
                            isSelected: viewModel.isSelected(item.id),
                            onToggle: {
                                viewModel.toggleSelection(for: item.id)
                            },
                            onReveal: {
                                viewModel.revealInFinder(url: item.path)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            } else if isExpanded && categoryItems.isEmpty {
                Divider()

                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("Clean & Optimal! No junk files found in this category.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
