import SwiftUI
import OneAccount
import URLKit
import DebugThings
import ButtonKit

enum ChangeEndpointFailure: Error, Equatable {
    case unsupportedAccount
    case differentBackend
}

enum EndpointChange {
    /// Canonical URL to store after discovery of a new address.
    /// Cloud accounts cannot move. Any other backend must match the stored one.
    static func canonicalURL(account: AccountRecord, url: URL, backend: Backend) throws -> URL {
        guard let expected = account.endpoint.backend, expected != .cloud else {
            throw ChangeEndpointFailure.unsupportedAccount
        }
        guard backend == expected else {
            throw ChangeEndpointFailure.differentBackend
        }
        return url
    }

    /// Probes the typed address exactly (https, then http when the scheme was omitted).
    /// Does not search other ports. The returned URL is the one Discovery reported.
    static func resolve(
        trimmedURL: String,
        account: AccountRecord,
        discovery: DiscoveryClient,
        session: URLSession
    ) async throws -> URL {
        guard account.endpoint.backend != .cloud, account.endpoint.backend != nil else {
            throw ChangeEndpointFailure.unsupportedAccount
        }
        let seeds = URL.endpointDiscoverySeeds(from: trimmedURL)
        guard !seeds.isEmpty else {
            throw WizardEndpointDiscovery.DiscoveryFailure.emptyInput
        }

        var sawDifferentBackend = false
        var lastError: Error?
        for seed in seeds {
            do {
                let found = try await discovery.exploreExact(seed, session, discovery.policy)
                if let url = try? canonicalURL(account: account, url: found.url, backend: found.backend) {
                    return url
                }
                sawDifferentBackend = true
            } catch {
                lastError = error
            }
        }
        if sawDifferentBackend {
            throw ChangeEndpointFailure.differentBackend
        }
        if let urlError = lastError as? URLError {
            throw WizardEndpointDiscovery.DiscoveryFailure.underlying(urlError)
        }
        throw WizardEndpointDiscovery.DiscoveryFailure.unsupportedBackend
    }
}

/// Replace the URL of an existing next, nextLegacy, or intl account after the old address is gone.
@MainActor
public struct ChangeEndpointForm: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var currentAccount: CurrentAccount

    private let account: AccountRecord
    private let discovery: DiscoveryClient
    private let authService: AuthService

    @State private var newURL: String = ""
    @State private var errorMessage: String?
    @State private var working = false

    public init(
        clientId: String,
        account: AccountRecord,
        discovery: DiscoveryClient,
        logger: (any URLSessionTaskLogger)? = nil
    ) {
        self.account = account
        self.discovery = discovery
        self.authService = AuthService(
            clientId: clientId,
            logger: logger,
            backendResolver: { _ in throw AuthServiceError.unsupportedBackend }
        )
    }

    public var body: some View {
        Form {
            Section {
                Text(account.endpoint.url.pretty())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } header: {
                Text("change-endpoint-current", bundle: .module)
            }

            Section {
                URLField(text: $newURL)
                    .onChange(of: newURL) { _ in
                        errorMessage = nil
                    }
            } header: {
                Text("change-endpoint-new", bundle: .module)
            } footer: {
                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else {
                    Text("change-endpoint-prompt", bundle: .module)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ActionButton(
                title: "change-server-address",
                accessibilityLabel: AccessibilityLabels.changeServerAddress,
                isDisabled: !canSubmit,
                action: changeAddress
            )
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("change-server-address", bundle: .module)
            }
        }
    }

    private var canSubmit: Bool {
        guard account.endpoint.backend != nil, account.endpoint.backend != .cloud else { return false }
        return !working && !newURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func changeAddress() async {
        working = true
        errorMessage = nil
        defer { working = false }
        do {
            let url = try await EndpointChange.resolve(
                trimmedURL: newURL,
                account: account,
                discovery: discovery,
                session: DiscoveryURLSession.make()
            )
            guard let backend = account.endpoint.backend else {
                throw ChangeEndpointFailure.unsupportedAccount
            }
            let outcome = try await authService.signIn(
                url: url,
                backend: backend,
                user: account.credentials.user,
                password: account.credentials.password,
                serverTrustPolicy: account.serverTrustPolicy
            )
            switch outcome {
            case .authenticated(let session):
                try await persist(url: url, session: session)
                dismiss()
            case .needsOtp:
                errorMessage = UserFacingErrorMessage.text(for: AuthServiceError.unsupportedBackend)
            }
        } catch {
            errorMessage = UserFacingErrorMessage.text(for: error)
        }
    }

    /// Stores the discovered URL, then the session just issued. The pin and password stay.
    private func persist(url: URL, session: BackendSession?) async throws {
        try await accountManager.store.updateEndpoint(accountID: account.id, url: url)
        if let session {
            try await accountManager.store.updateSession(accountID: account.id, session: session)
        }
        if currentAccount.selectedId == account.id {
            await currentAccount.selectAccount(id: account.id)
        }
        try await accountManager.refresh()
    }
}
