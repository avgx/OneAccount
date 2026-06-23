import Foundation
import SSLPinning
import TLSDiagnostics
import DebugThings
import Resource

public struct AccountCreationUseCases: Sendable {
    public var authService: AuthService

    public init(authService: AuthService) {
        self.authService = authService
    }

    public func loadCertificates(
        for endpoint: Endpoint,
        serverTrustPolicy: ServerTrustPolicy,
        current: CertificatePreview
    ) async -> CertificatePreview {
        let resource = current.beginLoading()
        do {
            let result = try await TLSProbe.inspect(for: endpoint.url, policy: serverTrustPolicy)
            return resource.succeed(CertificateProbeResult(result))
        } catch let error as SSLPinningError {
            if let result = Self.probeResult(from: error) {
                return resource.succeed(result)
            }
            return resource.fail(Self.failure(from: error))
        } catch let error as TLSProbe.Error {
            return resource.fail(Self.failure(from: error))
        } catch {
            return resource.fail(.handshakeFailed(description: error.localizedDescription))
        }
    }

    public func validateCredentials(_ request: AccountCredentialsRequest) async throws -> AccountSignInOutcome {
        guard let backend = request.endpoint.backend else {
            throw AuthServiceError.unsupportedBackend
        }

        let outcome = try await authService.signIn(
            url: request.endpoint.url,
            backend: backend,
            user: request.user,
            password: request.password,
            serverTrustPolicy: request.serverTrustPolicy
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
            mode: request.mode,
            serverTrustPolicy: request.serverTrustPolicy
        )
    }
}

private extension AccountCreationUseCases {
    static func probeResult(from error: SSLPinningError) -> CertificateProbeResult? {
        switch error {
        case .fingerprintMismatch(_, _, let presentedChain),
             .unknownHost(_, let presentedChain):
            CertificateProbeResult(chain: presentedChain, trustStatus: nil, pinningError: error)
        case .invalidServerTrust, .systemTrustFailed:
            nil
        }
    }

    static func failure(from error: SSLPinningError) -> CertificatePreviewFailure {
        switch error {
        case .invalidServerTrust(let host):
            .invalidServerTrust(host: host)
        case .systemTrustFailed(let underlying):
            .systemTrustFailed(description: underlying.localizedDescription)
        case .fingerprintMismatch, .unknownHost:
            .handshakeFailed(description: error.localizedDescription)
        }
    }

    static func failure(from error: TLSProbe.Error) -> CertificatePreviewFailure {
        switch error {
        case .notHTTPS:
            .notHTTPS
        case .noCertificates(let host):
            .noCertificates(host: host)
        case .handshakeFailed(let underlyingError):
            .handshakeFailed(description: underlyingError.localizedDescription)
        }
    }
}
