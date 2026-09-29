import SwiftUI

public struct CleanSummaryView: View {
    @ObservedObject var viewModel: SweepSpaceViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: SweepSpaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
            }

            VStack(spacing: 6) {
                Text("Mac Storage Cleaned!")
                    .font(.system(size: 20, weight: .bold))

                if let result = viewModel.lastCleanResult {
                    Text("Successfully reclaimed \(result.formattedCleaned)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)

                    Text("\(result.successCount) items removed safely")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Current Disk Status Box
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Capacity")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(viewModel.diskInfo.formattedTotal)
                        .font(.system(size: 13, weight: .semibold))
                }

                Divider().frame(height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Available Free Space")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(viewModel.diskInfo.formattedFree)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            Button("Done") {
                viewModel.isShowingCleanSummary = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 360)
    }
}
