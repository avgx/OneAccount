import Foundation
import SSLPinning
import TLSDiagnostics
import DebugThings

public struct AccountCreationUseCases: Sendable {
    public var authService: AuthService
    public var resolveEndpoint: @Sendable (String) async throws -> ResolvedEndpoint
    
    public init(
        authService: AuthService,
        resolveEndpoint: @Sendable @escaping (String) async throws -> ResolvedEndpoint
    ) {
        self.authService = authService
        self.resolveEndpoint = resolveEndpoint
    }

    public func loadCertificates(for endpoint: Endpoint, serverTrustPolicy: ServerTrustPolicy) async -> CertificatePreviewState {
        var state = CertificatePreviewState(isLoading: true)
        do {
            let res = try await TLSProbe.inspect(for: endpoint.url, policy: serverTrustPolicy)
            print("TLSProbe.inspect for \(endpoint.url.absoluteString): \(res)")
            state.chain = res.chain
            state.message = res.pinningError?.localizedDescription
        } catch let error as SSLPinningError {
            switch error {
            case .invalidServerTrust(let host):
                state.chain = []
                state.message = error.localizedDescription
            case .fingerprintMismatch(let host, let expected, let presentedChain):
                state.chain = presentedChain
                state.message = error.localizedDescription
            case .unknownHost(let host, let presentedChain):
                state.chain = presentedChain
                state.message = error.localizedDescription
            case .systemTrustFailed(let underlying):
                state.chain = []
                state.message = error.localizedDescription
            }
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
