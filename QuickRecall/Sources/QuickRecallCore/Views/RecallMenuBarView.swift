import SwiftUI
import AppKit

public struct RecallMenuBarView: View {
    @ObservedObject public var viewModel: QuickRecallViewModel
    public var onOpenSearch: (() -> Void)?

    public init(viewModel: QuickRecallViewModel, onOpenSearch: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onOpenSearch = onOpenSearch
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView

            // Memory Status Card
            memoryStatusCard

            // Big Search Trigger Button
            openSearchButton

            // Recording Controls
            recordingControlRow

            // Footer
            footerView
        }
        .padding(18)
        .frame(width: 320)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple, Color.indigo, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("QuickRecall")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }

            Spacer()

            // Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isRecording ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: viewModel.isRecording ? Color.green.opacity(0.8) : .clear, radius: 4)

                Text(viewModel.isRecording ? "Recording" : "Paused")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(viewModel.isRecording ? .green : .orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(12)
        }
    }

    private var memoryStatusCard: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Indexed Moments")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("\(viewModel.totalSnapshotsCount) Snapshots")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
            }

            Divider().opacity(0.1)

            HStack {
                Text("Last Activity:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(viewModel.lastCapturedAppName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if let date = viewModel.lastCapturedTime {
                    Text(timeAgo(from: date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var openSearchButton: some View {
        Button(action: {
            onOpenSearch?()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))

                Text("Search Memory")
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                Text("⌘⇧Space")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.indigo, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.purple.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var recordingControlRow: some View {
        HStack {
            Button(action: {
                viewModel.toggleRecording()
            }) {
                Label(viewModel.isRecording ? "Pause Recording" : "Resume Recording", systemImage: viewModel.isRecording ? "pause.fill" : "play.fill")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button(action: {
                viewModel.clearAllHistory()
            }) {
                Label("Clear All", systemImage: "trash")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var footerView: some View {
        HStack {
            Text("100% On-Device Neural OCR")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
        }
    }

    private func timeAgo(from date: Date) -> String {
        let sec = Int(-date.timeIntervalSinceNow)
        if sec < 60 { return "Just now" }
        return "\(sec / 60)m ago"
    }
}
