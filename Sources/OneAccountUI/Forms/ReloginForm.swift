import SwiftUI
import OneAccount
import DebugThings
import ButtonKit

/// Re-authenticate a stored cloud or Next account and persist new bearer tokens.
@MainActor
public struct ReloginForm: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountManager: AccountManager
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
            if otpModes == nil {
                credentialsStep
            } else {
                otpStep
            }
        }
        .onAppear {
            currentAccount.clearReloginPrompt()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                reloginToolbarTitle
            }
        }
    }
    
    @ViewBuilder
    var credentialsStep: some View {
        Section {
            UsernameField(text: .constant(account.credentials.user))
                .foregroundStyle(.secondary)
                .disabled(true)
            
            PasswordField(text: $password)
                .onChange(of: password) { _ in
                    resetLocalSignInState()
                }
        } header: {
            Text("credentials", bundle: .module)
        } footer: {
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else {
                Text("relogin-password-prompt", bundle: .module)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        ActionButton(
            title: "sign-in",
            isDisabled: working || password.isEmpty,
            action: signIn
        )
    }
    
    @ViewBuilder
    var otpStep: some View {
        OTPField(code: $otpCode, isTotp: $isTotp, canTotp: otpModes?.contains(.totp) ?? false)

        ActionButton(
            title: "verify",
            isDisabled: working || otpCode.count < 4,
            action: verifyOtp
        )
    }

    @ViewBuilder
    private var reloginToolbarTitle: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: account.endpoint.backend?.icon ?? "questionmark")
                Text(account.endpoint.url.pretty())
            }
        }
    }
    
    private func resetLocalSignInState() {
        errorMessage = nil
    }
    
    private func signIn() async {
        guard let backend = account.endpoint.backend else {
            errorMessage = UserFacingErrorMessage.text(for: AuthServiceError.unsupportedBackend)
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
                password: password,
                serverTrustPolicy: account.serverTrustPolicy
            )
            switch outcome {
            case .authenticated(let session):
                if let session {
                    try await persistSession(session)
                } else {
                    try await persistPassword(password)
                }
                
                dismiss()
            case .needsOtp(let modes):
                guard !modes.isEmpty else {
                    errorMessage = UserFacingErrorMessage.text(for: AuthServiceError.invalidResponse)
                    return
                }
                otpModes = modes
                isTotp = modes.count == 1 && modes[0] == .totp
                otpCode = ""
            }
        } catch {
            errorMessage = ErrorHelper.connectionFailureMessage(for: error)
        }
    }

    private func verifyOtp() async {
        guard let modes = otpModes, !modes.isEmpty else { return }
        let mode: OtpMode = isTotp ? .totp : .otp
        guard modes.contains(mode) else {
            errorMessage = L10n.string("select-verification-method")
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
                mode: mode,
                serverTrustPolicy: account.serverTrustPolicy
            )
            try await persistSession(session)
            dismiss()
        } catch {
            errorMessage = ErrorHelper.connectionFailureMessage(for: error)
        }
    }

    private func persistSession(_ session: BackendSession?) async throws {
        try await accountManager.store.updateSession(accountID: account.id, session: session)
        if currentAccount.selectedId == account.id {
            await currentAccount.selectAccount(id: account.id)
        }
        try await accountManager.refresh()
    }
    
    private func persistPassword(_ password: String) async throws {
        try await accountManager.store.updatePassword(accountID: account.id, password: password)
        if currentAccount.selectedId == account.id {
            await currentAccount.selectAccount(id: account.id)
        }
        try await accountManager.refresh()
    }
}
