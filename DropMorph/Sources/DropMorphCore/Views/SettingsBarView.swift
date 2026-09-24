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

            // Controls Row: Mode Toggle, Quality / Target Size, Resize, Privacy
            HStack(spacing: 14) {
                // Mode Toggle
                HStack(spacing: 2) {
                    ForEach(CompressionMode.allCases) { mode in
                        let isSelected = viewModel.settings.mode == mode
                        Button {
                            viewModel.settings.mode = mode
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mode == .quality ? "slider.horizontal.3" : "scalemass.fill")
                                    .font(.system(size: 9))
                                Text(mode.rawValue)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.blue.opacity(0.18) : Color.clear)
                            )
                            .foregroundColor(isSelected ? .blue : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                )

                Divider()
                    .frame(height: 16)

                // Mode-dependent control
                if viewModel.settings.mode == .quality {
                    // Quality Slider
                    if viewModel.settings.targetFormat == .webp ||
                       viewModel.settings.targetFormat == .jpeg ||
                       viewModel.settings.targetFormat == .heic {
                        HStack(spacing: 6) {
                            Text("Quality:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)

                            Slider(value: $viewModel.settings.quality, in: 0.1...1.0, step: 0.05)
                                .frame(width: 85)

                            Text("\(Int(round(viewModel.settings.quality * 100)))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                                .frame(width: 36, alignment: .leading)
                        }
                    } else {
                        Text("Auto Quality")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Target Size Controls: Quick Chips + Stepper
                    HStack(spacing: 6) {
                        Text("Target:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        // Quick Presets
                        HStack(spacing: 3) {
                            ForEach([1.0, 2.0, 5.0, 10.0, 25.0], id: \.self) { mb in
                                let isSelected = abs(viewModel.settings.targetSizeMB - mb) < 0.05
                                Button {
                                    viewModel.settings.targetSizeMB = mb
                                } label: {
                                    Text(mb == 25.0 ? "25M" : "\(Int(mb))M")
                                        .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2.5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .fill(isSelected ? Color.blue : Color.primary.opacity(0.06))
                                        )
                                        .foregroundColor(isSelected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Stepper for custom MB
                        HStack(spacing: 3) {
                            Button {
                                let step = viewModel.settings.targetSizeMB > 1.0 ? 0.5 : 0.1
                                viewModel.settings.targetSizeMB = max(0.1, (viewModel.settings.targetSizeMB - step))
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)

                            Text(String(format: "%.1f MB", viewModel.settings.targetSizeMB))
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                                .frame(minWidth: 46, alignment: .center)

                            Button {
                                let step = viewModel.settings.targetSizeMB >= 1.0 ? 0.5 : 0.1
                                viewModel.settings.targetSizeMB = min(500.0, (viewModel.settings.targetSizeMB + step))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                // Resize Picker
                HStack(spacing: 4) {
                    Text("Scale:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("", selection: $viewModel.settings.resizePreset) {
                        ForEach(ResizePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 115)
                }

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
