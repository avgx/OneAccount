import Foundation
import SSLPinning

public struct AccountCreationUseCases: Sendable {
    public var authService: AuthService
    public var serverTrustPolicy: ServerTrustPolicy

    public init(authService: AuthService, serverTrustPolicy: ServerTrustPolicy = .system) {
        self.authService = authService
        self.serverTrustPolicy = serverTrustPolicy
    }

    public func resolveEndpoint(_ input: EndpointInput) async throws -> ResolvedEndpoint {
        let trimmed = input.rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await WizardEndpointDiscovery.resolveEndpoint(trimmedURL: trimmed)
        return ResolvedEndpoint(url: result.url, backend: result.backend)
    }

    public func loadCertificates(for endpoint: Endpoint) async -> CertificatePreviewState {
        var state = CertificatePreviewState(isLoading: true)
        do {
            state.chain = try await HTTPSCertificateProbe.fetchCertificateChain(
                url: endpoint.url,
                serverTrustPolicy: serverTrustPolicy
            )
            state.message = nil
        } catch {
            state.chain = []
            state.message = error.localizedDescription
        }
        state.isLoading = false
        return state
    }

    public func validateCredentials(_ request: AccountCredentialsRequest) async throws -> AccountSignInOutcome {
        guard let backend = request.endpoint.backend else {
            throw AuthServiceError.unsupportedBackend
        }

        let outcome = try await authService.signIn(
            url: request.endpoint.url,
            backend: backend,
            user: request.user,
            password: request.password
        )

        switch outcome {
        case .authenticated(let session):
            return .authenticated(session: session)
        case .needsOtp(let modes):
            return .needsOtp(canTotp: modes.contains(.totp))
        }
    }

    public func verifyOtp(_ request: OTPVerificationRequest) async throws -> BackendSession {
        try await authService.verifyOtp(
            url: request.endpoint.url,
            user: request.user,
            code: request.code,
            mode: request.mode
        )
    }
}
