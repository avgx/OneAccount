import SwiftUI
import OneAccount
import DebugThings

/// Re-authenticate a stored cloud or Next account and persist new bearer tokens.
@MainActor
public struct ReloginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountsViewModel: AccountsViewModel
    @EnvironmentObject private var currentAccount: CurrentAccount

    private let clientId: String
    
    private let account: AccountRecord
    private let authService: AuthService

    @State private var password: String = ""
    @State private var otpCode: String = ""
    @State private var isTotp: Bool = false
    @State private var otpModes: [OtpMode]?
    @State private var errorMessage: String?
    @State private var working = false

    public init(
        clientId: String,
        account: AccountRecord,
        logger: (any URLSessionTaskLogger)? = nil
    ) {
        self.clientId = clientId
        self.account = account
        self.authService = AuthService(
            clientId: clientId,
            logger: logger,
            backendResolver: { _ in throw AuthServiceError.unsupportedBackend }
        )
    }

    public var body: some View {
        Form {
            Section {
                FormLabeledValue("URL") {
                    Text(account.endpoint.url.absoluteString)
                        .font(.caption)
#if !os(tvOS)
                        .textSelection(.enabled)
#endif
                }
                if let b = account.endpoint.backend {
                    FormLabeledValue("Backend") {
                        Text(b.rawValue)
                    }
                }
                FormLabeledValue("User") {
                    Text(account.credentials.user)
#if !os(tvOS)
                        .textSelection(.enabled)
#endif
                }
            } header: {
                Text("Account")
            }

            if otpModes == nil {
                Section {
                    SecureField("Password", text: $password)
                } header: {
                    Text("Credentials")
                } footer: {
                    Text("Enter your password to obtain new session tokens.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(action: { Task { await signIn() } }) {
                        HStack {
                            Spacer()
                            if working {
                                ProgressView()
                            } else {
                                Text("Sign in")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(working || password.isEmpty)
                }
            } else {
                OTPField(code: $otpCode, isTotp: $isTotp, canTotp: otpModes?.contains(.totp) ?? false)

                Section {
                    Button(action: { Task { await verifyOtp() } }) {
                        HStack {
                            Spacer()
                            if working {
                                ProgressView()
                            } else {
                                Text("Verify")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(working || otpCode.count < 4)
                }
            }
        }
        .navigationTitle("Re-login")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            currentAccount.clearReloginPrompt()
        }
    }

    private func signIn() async {
        guard let backend = account.endpoint.backend else {
            errorMessage = AuthServiceError.unsupportedBackend.localizedDescription
            return
        }
        working = true
        errorMessage = nil
        defer { working = false }
        do {
            let url = account.endpoint.url
            let outcome = try await authService.signIn(
                url: url,
                backend: backend,
                user: account.credentials.user,
                password: password
            )
            switch outcome {
            case .authenticated(let session):
                guard let session else {
                    errorMessage = AuthServiceError.noTokens.localizedDescription
                    return
                }
                try await persistSession(session)
                dismiss()
            case .needsOtp(let modes):
                guard !modes.isEmpty else {
                    errorMessage = AuthServiceError.invalidResponse.localizedDescription
                    return
                }
                otpModes = modes
                isTotp = modes.count == 1 && modes[0] == .totp
                otpCode = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verifyOtp() async {
        guard let modes = otpModes, !modes.isEmpty else { return }
        let mode: OtpMode = isTotp ? .totp : .otp
        guard modes.contains(mode) else {
            errorMessage = "Select a supported verification method."
            return
        }
        working = true
        errorMessage = nil
        defer { working = false }
        do {
            let session = try await authService.verifyOtp(
                url: account.endpoint.url,
                user: account.credentials.user,
                code: otpCode,
                mode: mode
            )
            try await persistSession(session)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistSession(_ session: BackendSession?) async throws {
        try await accountsViewModel.store.updateSession(accountID: account.id, session: session)
        if currentAccount.selectedId == account.id {
            await currentAccount.selectAccount(id: account.id)
        }
        try await accountsViewModel.refresh()
    }
}
