import SwiftUI
import AppKit

public struct PasswordRecoverySheet: View {
    @ObservedObject var archiveViewModel: ArchiveViewModel
    @StateObject private var recoveryViewModel = PasswordRecoveryViewModel()
    @Environment(\.dismiss) private var dismiss

    public init(archiveViewModel: ArchiveViewModel) {
        self.archiveViewModel = archiveViewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Password Recovery Assistant")
                        .font(.system(size: 16, weight: .bold))

                    Text("Automatically test high-probability passwords and candidate clues.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    recoveryViewModel.cancel()
                    archiveViewModel.isShowingRecoverySheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Strategy Selector
            Picker("Strategy", selection: $recoveryViewModel.selectedStrategy) {
                ForEach(RecoveryStrategyType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .disabled(recoveryViewModel.isRunning)

            // Dynamic Options according to selected strategy
            strategyOptionsView

            // Live progress & Status Card
            statusCardView

            // Found password banner if discovered
            if let found = recoveryViewModel.foundPassword {
                successBannerView(password: found)
            }

            Spacer()

            Divider()

            // Bottom Action buttons
            actionButtonsView
        }
        .padding(20)
        .frame(width: 460, height: 480)
    }

    @ViewBuilder
    private var strategyOptionsView: some View {
        switch recoveryViewModel.selectedStrategy {
        case .common:
            VStack(alignment: .leading, spacing: 4) {
                Text("Tests 150+ high-probability passwords (e.g. 1234, 123456, clip, hd, vip, free, admin, pass, forum release tags).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

        case .numericPin:
            HStack(spacing: 12) {
                Text("PIN Length:")
                    .font(.system(size: 12, weight: .medium))

                Picker("", selection: $recoveryViewModel.pinLength) {
                    Text("4 Digits (0000 - 9999)").tag(4)
                    Text("6 Digits (000000 - 999999)").tag(6)
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                .disabled(recoveryViewModel.isRunning)

                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

        case .customWords:
            VStack(alignment: .leading, spacing: 6) {
                Text("Candidate Clues (comma or line separated):")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                TextEditor(text: $recoveryViewModel.customWordsText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 70)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .disabled(recoveryViewModel.isRunning)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        }
    }

    private var statusCardView: some View {
        VStack(spacing: 10) {
            HStack {
                Text(recoveryViewModel.statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                if recoveryViewModel.candidatesPerSecond > 0 && recoveryViewModel.isRunning {
                    Text("\(Int(recoveryViewModel.candidatesPerSecond)) tests/s")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }

            ProgressView(value: recoveryViewModel.progress)
                .progressViewStyle(.linear)

            if !recoveryViewModel.currentCandidate.isEmpty && recoveryViewModel.isRunning {
                HStack(spacing: 6) {
                    Text("Testing:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(recoveryViewModel.currentCandidate)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func successBannerView(password: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text("Password Found!")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)

                Text(password)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(password, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                Text("Copy")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            if recoveryViewModel.foundPassword != nil {
                Button("Close") {
                    archiveViewModel.isShowingRecoverySheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    if let found = recoveryViewModel.foundPassword {
                        archiveViewModel.applyRecoveredPassword(found)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open.fill")
                        Text("Apply & Unlock Archive")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else if recoveryViewModel.isRunning {
                Button("Stop") {
                    recoveryViewModel.cancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Cancel") {
                    archiveViewModel.isShowingRecoverySheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    if let url = archiveViewModel.currentArchive?.fileURL {
                        recoveryViewModel.startRecovery(for: url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Start Recovery")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(archiveViewModel.currentArchive == nil)
            }
        }
    }
}
