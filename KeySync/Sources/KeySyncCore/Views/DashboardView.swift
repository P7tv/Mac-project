import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject public var viewModel: KeySyncViewModel
    @State private var copiedCommand: Bool = false

    public init(viewModel: KeySyncViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Background Theme
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.10),
                    Color(red: 0.08, green: 0.07, blue: 0.18),
                    Color(red: 0.04, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    headerView
                    
                    if !viewModel.hasAccessibilityPermission {
                        accessibilityBanner
                    }

                    monitorArrangementCard
                    
                    connectionCard

                    liveActivityCard

                    footerActionCard
                }
                .padding(22)
            }
        }
        .frame(minWidth: 560, idealWidth: 580, maxWidth: 620, minHeight: 640, idealHeight: 680)
        .onAppear {
            viewModel.checkPermissions()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.55, green: 0.35, blue: 0.95), Color(red: 0.38, green: 0.25, blue: 0.90)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .shadow(color: Color.purple.opacity(0.35), radius: 8, x: 0, y: 4)

                Image(systemName: "keyboard.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("KeySync")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("v1.1")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.25)))
                        .foregroundColor(Color(red: 0.75, green: 0.65, blue: 1.0))
                }

                Text("Universal Mac & Windows Keyboard/Mouse Sharing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Connection Status Pill
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
                    .shadow(color: statusColor.opacity(0.6), radius: 4)

                Text(statusText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.12))
                    .overlay(Capsule().stroke(statusColor.opacity(0.25), lineWidth: 1))
            )
        }
    }

    private var statusColor: Color {
        if viewModel.isControllingRemote {
            return Color.cyan
        } else if viewModel.isClientConnected {
            return Color.green
        } else {
            return Color.orange
        }
    }

    private var statusText: String {
        if viewModel.isControllingRemote {
            return "Controlling Windows"
        } else if viewModel.isClientConnected {
            return "PC Connected"
        } else {
            return "Waiting for PC"
        }
    }

    // MARK: - Accessibility Permission Banner
    private var accessibilityBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 3) {
                Text("Accessibility Permission Required")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Text("KeySync requires Accessibility access to lock the cursor and forward keystrokes seamlessly.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()

            Button {
                viewModel.requestAccessibilityPermission()
            } label: {
                Text("Authorize")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow))
            }
            .buttonStyle(.plain)

            Button {
                viewModel.checkPermissions()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(6)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.35), lineWidth: 1))
        )
    }

    // MARK: - Monitor Arrangement Visualizer
    private var monitorArrangementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Display Glide Arrangement", systemImage: "rectangle.split.2x1")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("Push cursor through selected border")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }

            // Interactive Monitor Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    .frame(height: 150)

                monitorLayoutPreview
            }

            // Edge Switcher Tabs
            HStack(spacing: 8) {
                ForEach(ScreenEdge.allCases) { edge in
                    edgeButton(for: edge)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    @ViewBuilder
    private var monitorLayoutPreview: some View {
        if viewModel.selectedEdge == .right || viewModel.selectedEdge == .left {
            HStack(spacing: 16) {
                if viewModel.selectedEdge == .right {
                    macScreenView(isCurrent: !viewModel.isControllingRemote)
                    glideIndicator(direction: .horizontal)
                    pcScreenView(isCurrent: viewModel.isControllingRemote)
                } else {
                    pcScreenView(isCurrent: viewModel.isControllingRemote)
                    glideIndicator(direction: .horizontal)
                    macScreenView(isCurrent: !viewModel.isControllingRemote)
                }
            }
        } else {
            VStack(spacing: 10) {
                if viewModel.selectedEdge == .bottom {
                    macScreenView(isCurrent: !viewModel.isControllingRemote)
                    glideIndicator(direction: .vertical)
                    pcScreenView(isCurrent: viewModel.isControllingRemote)
                } else {
                    pcScreenView(isCurrent: viewModel.isControllingRemote)
                    glideIndicator(direction: .vertical)
                    macScreenView(isCurrent: !viewModel.isControllingRemote)
                }
            }
        }
    }

    private func macScreenView(isCurrent: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCurrent ? Color.blue.opacity(0.25) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCurrent ? Color.blue : Color.white.opacity(0.15), lineWidth: isCurrent ? 2 : 1)
                    )
                    .frame(width: 140, height: 80)

                VStack(spacing: 3) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 20))
                    Text("Mac (Host)")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(isCurrent ? .cyan : .white.opacity(0.6))
            }
        }
    }

    private func pcScreenView(isCurrent: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCurrent ? Color.purple.opacity(0.3) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCurrent ? Color.purple : Color.white.opacity(0.15), lineWidth: isCurrent ? 2 : 1)
                    )
                    .frame(width: 140, height: 80)

                VStack(spacing: 3) {
                    Image(systemName: "display")
                        .font(.system(size: 20))
                    Text("Windows (Client)")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(isCurrent ? Color(red: 0.75, green: 0.65, blue: 1.0) : .white.opacity(0.6))
            }
        }
    }

    private enum GlideDirection { case horizontal, vertical }

    private func glideIndicator(direction: GlideDirection) -> some View {
        Group {
            if direction == .horizontal {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.cyan.opacity(0.8))
            } else {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.cyan.opacity(0.8))
            }
        }
    }

    private func edgeButton(for edge: ScreenEdge) -> some View {
        let isSelected = viewModel.selectedEdge == edge
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedEdge = edge
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: edgeIcon(for: edge))
                    .font(.system(size: 11))
                Text(edge.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.purple.opacity(0.3) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1.5)
                    )
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }

    private func edgeIcon(for edge: ScreenEdge) -> String {
        switch edge {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .top: return "arrow.up"
        case .bottom: return "arrow.down"
        }
    }

    // MARK: - Connection Card
    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Windows Setup & Connection", systemImage: "network")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            connectionDetailsRow

            Text("On Windows, install `pip install pynput` then run: `python keysync_client.py \(viewModel.localIP)`")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private var connectionDetailsRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mac Host Address:")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                Text("\(viewModel.localIP):\(viewModel.port)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.cyan)
            }

            Spacer()

            copyButton
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.25)))
    }

    private var copyButton: some View {
        Button {
            viewModel.copyClientCommand()
            copiedCommand = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                copiedCommand = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: copiedCommand ? "checkmark.circle.fill" : "doc.on.doc")
                Text(copiedCommand ? "Copied!" : "Copy Python Command")
            }
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(copiedCommand ? Color.green.opacity(0.2) : Color.purple.opacity(0.25))
            )
            .foregroundColor(copiedCommand ? .green : .white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Live Activity Inspector
    private var liveActivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Live Event Inspector", systemImage: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isControllingRemote ? Color.cyan : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isControllingRemote ? "Forwarding Active" : "Standby")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Latest Event:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Text(viewModel.lastEventDescription)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Spacer()
                }

                if !viewModel.eventLog.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.eventLog.prefix(4), id: \.self) { item in
                            Text(item)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.4)))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    // MARK: - Emergency Panic Release & Actions
    private var footerActionCard: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.panicRelease()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 14))
                    Text("Emergency Release to Mac")
                        .font(.system(size: 12, weight: .bold))
                    Text("(Esc)")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red.opacity(0.4)))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.2))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.6), lineWidth: 1))
                )
                .foregroundColor(.red)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.toggleRunning()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                    Text(viewModel.isRunning ? "Stop Service" : "Start Service")
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewModel.isRunning ? Color.white.opacity(0.1) : Color.green.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.isRunning ? Color.white.opacity(0.2) : Color.green.opacity(0.6), lineWidth: 1)
                        )
                )
                .foregroundColor(viewModel.isRunning ? .white.opacity(0.8) : .green)
            }
            .buttonStyle(.plain)
        }
    }
}
