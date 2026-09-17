import SwiftUI

public struct DisplaySettingsBar: View {
    @ObservedObject var viewModel: DeskExtendViewModel

    public init(viewModel: DeskExtendViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Resolution Picker
                HStack(spacing: 6) {
                    Image(systemName: "display")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Resolution:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.selectedResolution) {
                        ForEach(DisplayResolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                    .disabled(viewModel.isStreaming)
                }

                // FPS Picker
                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("FPS:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.targetFPS) {
                        Text("60 FPS (Ultra Smooth)").tag(60)
                        Text("30 FPS (Power Saver)").tag(30)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .disabled(viewModel.isStreaming)
                }

                Spacer()
            }

            // Quality & Settings Shortcut
            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    Text("Quality:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Slider(value: $viewModel.streamQuality, in: 0.4...0.95, step: 0.05)
                        .frame(width: 100)

                    Text("\(Int(round(viewModel.streamQuality * 100)))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                        .frame(width: 36, alignment: .leading)
                }

                Spacer()

                Button {
                    viewModel.openDisplaySettings()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("Arrange Displays in macOS")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.link)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}
