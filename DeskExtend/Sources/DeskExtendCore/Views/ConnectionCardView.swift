import SwiftUI

public struct ConnectionCardView: View {
    let address: NetworkAddress
    var onCopy: () -> Void
    @State private var isCopied: Bool = false

    public init(address: NetworkAddress, onCopy: @escaping () -> Void) {
        self.address = address
        self.onCopy = onCopy
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: badgeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(badgeColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(address.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    if address.type == .linkLocal {
                        Text("Fastest")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.green.opacity(0.2)))
                            .foregroundColor(.green)
                    }
                }

                Text(address.urlString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.blue)
            }

            Spacer()

            Button {
                onCopy()
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isCopied = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                    Text(isCopied ? "Copied!" : "Copy URL")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isCopied ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                )
                .foregroundColor(isCopied ? .green : .primary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var badgeColor: Color {
        switch address.type {
        case .wifi: return .blue
        case .ethernet, .linkLocal: return .green
        case .localhost: return .gray
        }
    }

    private var badgeIcon: String {
        switch address.type {
        case .wifi: return "wifi"
        case .ethernet, .linkLocal: return "cable.connector"
        case .localhost: return "laptopcomputer"
        }
    }
}
