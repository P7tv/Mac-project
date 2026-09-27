import SwiftUI

public struct PasswordPromptView: View {
    @ObservedObject var viewModel: ArchiveViewModel
    @State private var password: String = ""
    @State private var showPassword: Bool = false

    public init(viewModel: ArchiveViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            VStack(spacing: 6) {
                Text("Password Protected Archive")
                    .font(.system(size: 16, weight: .bold))

                Text("Enter the password to decrypt and view this archive.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                if showPassword {
                    TextField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 260)

            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.isShowingPasswordPrompt = false
                    if viewModel.currentArchive == nil {
                        viewModel.closeArchive()
                    }
                }
                .keyboardShortcut(.cancelAction)

                Button("Unlock") {
                    viewModel.passwordInput = password
                    viewModel.isShowingPasswordPrompt = false
                    if let archiveURL = viewModel.currentArchive?.fileURL {
                        Task {
                            await viewModel.loadArchive(url: archiveURL, password: password)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
            }

            Divider()

            Button {
                viewModel.isShowingPasswordPrompt = false
                viewModel.isShowingRecoverySheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(.orange)
                    Text("Forgot Password? Use Recovery")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 340)
    }
}
