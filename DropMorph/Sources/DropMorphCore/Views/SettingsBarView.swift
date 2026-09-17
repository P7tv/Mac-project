import SwiftUI

public struct SettingsBarView: View {
    @ObservedObject var viewModel: ConversionViewModel

    public init(viewModel: ConversionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Format Selector Bar
            HStack(spacing: 8) {
                Text("Format:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(OutputFormat.allCases) { format in
                            let isSelected = viewModel.settings.targetFormat == format
                            Button {
                                viewModel.settings.targetFormat = format
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: format.systemImage)
                                        .font(.system(size: 11))
                                    Text(format.displayName)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected ? Color.blue : Color.primary.opacity(0.06))
                                )
                                .foregroundColor(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                        }
                    }
                }
            }

            // Controls Row: Quality, Resize, Privacy
            HStack(spacing: 18) {
                // Quality Slider (for lossy formats)
                if viewModel.settings.targetFormat == .webp ||
                   viewModel.settings.targetFormat == .jpeg ||
                   viewModel.settings.targetFormat == .heic {
                    HStack(spacing: 8) {
                        Text("Quality:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Slider(value: $viewModel.settings.quality, in: 0.1...1.0, step: 0.05)
                            .frame(width: 100)

                        Text("\(Int(round(viewModel.settings.quality * 100)))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                            .frame(width: 38, alignment: .leading)
                    }
                }

                // Resize Picker
                HStack(spacing: 6) {
                    Text("Scale:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.settings.resizePreset) {
                        ForEach(ResizePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }

                Spacer()

                // Metadata toggle
                Toggle(isOn: $viewModel.settings.stripMetadata) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.settings.stripMetadata ? "lock.shield.fill" : "shield")
                            .font(.system(size: 11))
                            .foregroundColor(viewModel.settings.stripMetadata ? .green : .secondary)
                        Text("Strip EXIF")
                            .font(.system(size: 11))
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}
