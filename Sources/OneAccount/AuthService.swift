import Foundation
import HTTP
import RequestResponse
import DebugThings
import SSLPinning

public enum OtpMode: Hashable, Sendable {
    case otp
    case totp
}

public enum SignInOutcome: Sendable, Equatable {
    case authenticated(session: BackendSession?)
    case needsOtp(mode: [OtpMode])
}

public enum AuthServiceError: LocalizedError {
    case invalidResponse
    case unsupportedBackend
    case noTokens

    /// Cloud ac-backend: `error.otp.wrong`
    case cloudOtpWrong(values: OtpErrorValue?)
    /// Cloud ac-backend: `error.otp.too.many.failed.attempts`
    case cloudOtpTooManyFailedAttempts(values: OtpErrorValue?)
    /// Cloud ac-backend: `error.totp.invalid.code`
    case cloudTotpInvalidCode(values: OtpErrorValue?)
    /// Cloud ac-backend: `error.wrong.password`
    case cloudWrongPassword
    /// Cloud ac-backend: `error.not.authenticated`
    case cloudNotAuthenticated
    /// Cloud ac-backend: `error.session.is.inactive`
    case cloudSessionInactive
    /// Cloud ac-backend: `error.number.of.connection.user.sessions.exceeded`
    case cloudConcurrentSessionLimitExceeded
    /// Cloud ac-backend: other or unparsed error payload.
    case cloudBackendRejected(key: String?, detail: String, values: OtpErrorValue?)

    /// Next (gRPC) authenticate endpoint returned a non-OK code.
    case nextAuthRejected(code: EAuthenticateCode?, detail: String?)
    /// Server requires two-factor authentication; full flow not implemented yet.
    case nextSecondFactorRequired

    public var errorDescription: String? {
        switch self {
        case .cloudOtpWrong, .cloudOtpTooManyFailedAttempts, .cloudTotpInvalidCode,
                .cloudWrongPassword, .cloudNotAuthenticated, .cloudSessionInactive,
                .cloudConcurrentSessionLimitExceeded,
                .cloudBackendRejected:
            CloudErrorMessage.userText(for: self)
        case .invalidResponse:
            "Invalid server response."
        case .unsupportedBackend:
            "Unsupported backend."
        case .noTokens:
            "Auth succeeded but no tokens returned."
        case .nextSecondFactorRequired:
            "Two-factor authentication is required for this account."
        case .nextAuthRejected(let code, let detail):
            Self.message(for: code, detail: detail)
        }
    }
    
    private static func message(for code: EAuthenticateCode?, detail: String?) -> String {
        if let detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return detail
        }
        switch code {
        case .none:
            return "Sign-in failed."
        case .AUTHENTICATE_CODE_OK:
            return "Signed in."
        case .AUTHENTICATE_CODE_WRONG_CREDENTIALS, .AUTHENTICATE_CODE_PASSWORD_INVALID:
            return "Invalid username or password."
        case .AUTHENTICATE_CODE_USER_LOCKED:
            return "This user account is locked."
        case .AUTHENTICATE_CODE_IP_BLOCKED:
            return "Access from this network address is blocked."
        case .AUTHENTICATE_CODE_ALREADY_LOGGED:
            return "User is already logged in elsewhere."
        case .AUTHENTICATE_CODE_WRONG_SUPERVISOR_ROLE:
            return "Insufficient role for sign-in."
        case .AUTHENTICATE_CODE_TIMEZONE_DENIED:
            return "Sign-in denied for this time zone."
        case .AUTHENTICATE_CODE_SECOND_FACTOR_AUTH_NEEDED:
            return "Two-factor authentication is required for this account."
        case .AUTHENTICATE_CODE_TFA_WRONG_CODE:
            return "Incorrect two-factor code."
        case .AUTHENTICATE_CODE_TFA_NOT_ENABLED:
            return "Two-factor authentication is not enabled for this account."
        case .AUTHENTICATE_CODE_TFA_TYPE_MISMATCH, .AUTHENTICATE_CODE_TFA_TYPE_UNSUPPORTED:
            return "Unsupported two-factor method."
        case .AUTHENTICATE_CODE_TFA_ATTEMPT_LIMIT_EXCEEDED:
            return "Too many two-factor attempts."
        case .AUTHENTICATE_CODE_TFA_TIME_EXCEEDED:
            return "Two-factor verification timed out."
        case .AUTHENTICATE_CODE_GENERAL_ERROR:
            return "Sign-in failed."
        }
    }

    /// True when Cloud ac-backend rejected the request because the account has too many concurrent sessions
    /// (`error.number.of.connection.user.sessions.exceeded`).
    public static func isCloudConcurrentSessionLimitExceeded(_ error: Error) -> Bool {
        guard let e = error as? AuthServiceError else { return false }
        if case .cloudConcurrentSessionLimitExceeded = e { return true }
        return false
    }
}

/// Maps Next `authenticate` JSON failures to ``AuthServiceError``; internal for unit tests via `@testable`.
enum NextAuthFailureMapping {
    static func authServiceError(response: GrpcAuthResponse) -> AuthServiceError {
        let code = response.error_code
        let general = response.error_description
        
        if code == .AUTHENTICATE_CODE_SECOND_FACTOR_AUTH_NEEDED {
            return .nextSecondFactorRequired
        }
        
        if code == .AUTHENTICATE_CODE_GENERAL_ERROR && general?.reached_connection_limit == true {
            let msg = general?.description ?? "Connection limit reached for this account."
            return .nextAuthRejected(code: code, detail: msg)
        }
        
        if let d = general?.description, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .nextAuthRejected(code: code, detail: d)
        }
        
        return .nextAuthRejected(code: code, detail: nil)
    }
}

public struct AuthService: Sendable {
    public let clientId: String
    private let logger: (any URLSessionTaskLogger)?
    private var backendResolver: @Sendable (URL) async throws -> Backend
    
    public init(clientId: String, logger: (any URLSessionTaskLogger)? = nil, backendResolver: @Sendable @escaping (URL) async throws -> Backend) {
        self.clientId = clientId
        self.logger = logger
        self.backendResolver = backendResolver
    }
    
    public func signIn(
        url: URL,
        user: String,
        password: String,
        serverTrustPolicy: ServerTrustPolicy = .system
    ) async throws -> SignInOutcome {
        let backendResolved: Backend = try await backendResolver(url)
        return try await self.signIn(
            url: url,
            backend: backendResolved,
            user: user,
            password: password,
            serverTrustPolicy: serverTrustPolicy
        )
    }
    
    public func signIn(
        url: URL,
        backend: Backend,
        user: String,
        password: String,
        serverTrustPolicy: ServerTrustPolicy = .system
    ) async throws -> SignInOutcome {
        switch backend {
        case .cloud:
            return try await signInCloud(
                baseURL: url,
                user: user,
                password: password,
                serverTrustPolicy: serverTrustPolicy
            )
        case .next:
            return try await signInNext(
                baseURL: url,
                user: user,
                password: password,
                serverTrustPolicy: serverTrustPolicy
            )
        case .nextLegacy, .intl:
            _ = try await signInBasic(
                baseURL: url,
                backend: backend,
                user: user,
                password: password,
                serverTrustPolicy: serverTrustPolicy
            )
            return .authenticated(session: nil)
        }
    }
    
    public func verifyOtp(
        url: URL,
        user: String,
        code: String,
        mode: OtpMode,
        serverTrustPolicy: ServerTrustPolicy = .system
    ) async throws -> BackendSession {
        let builder = RequestBuilder.json(baseURL: url, encoder: JSONEncoder())
        let client = HTTPClient(
            serverTrustPolicy: serverTrustPolicy,
            logger: logger ?? NoopURLSessionTaskLogger()
        )
        let request = mode == .totp
            ? CloudApi.totpVerify(.init(email: user, totp: code, clientId: clientId))
            : CloudApi.otpVerify(.init(email: user, otp: code, clientId: clientId))

        do {
            let response = try await client.send(request, with: builder).value
            guard let accessToken = response.accessToken, let refreshToken = response.refreshToken else {
                throw AuthServiceError.noTokens
            }
            return .cloud(.init(accessToken: accessToken, refreshToken: refreshToken))
        } catch let error as HTTPError {
            throw CloudErrorMapping.authServiceError(from: error)
        }
    }
}

private extension AuthService {
    func signInCloud(
        baseURL: URL,
        user: String,
        password: String,
        serverTrustPolicy: ServerTrustPolicy
    ) async throws -> SignInOutcome {
        let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
        let client = HTTPClient(
            serverTrustPolicy: serverTrustPolicy,
            logger: logger ?? NoopURLSessionTaskLogger()
        )
        do {
            let response = try await client.send(
                CloudApi.login(.init(email: user, password: password, locale: Locale.current.identifier, clientId: clientId)),
                with: builder
            ).value

            if response.needOTPCheck == true {
                var mode: [OtpMode] = []
                if response.enabledOTP == true {
                    mode.append(.otp)
                }
                if (response.totpEnabledProviders ?? []).contains("microsoft") {
                    mode.append(.totp)
                }

                return .needsOtp(mode: mode)
            }

            guard let accessToken = response.accessToken, let refreshToken = response.refreshToken else {
                throw AuthServiceError.noTokens
            }
            return .authenticated(session: .cloud(.init(accessToken: accessToken, refreshToken: refreshToken)))
        } catch let error as HTTPError {
            throw CloudErrorMapping.authServiceError(from: error)
        }
    }
    
    func signInNext(
        baseURL: URL,
        user: String,
        password: String,
        serverTrustPolicy: ServerTrustPolicy
    ) async throws -> SignInOutcome {
        let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
        let client = HTTPClient(
            serverTrustPolicy: serverTrustPolicy,
            logger: logger ?? NoopURLSessionTaskLogger()
        )
        let response = try await client.send(
            NextApi.authenticate(user: user, password: password),
            with: builder
        ).value
        
        guard response.error_code == .AUTHENTICATE_CODE_OK else {
            throw NextAuthFailureMapping.authServiceError(response: response)
        }
        guard let token = response.token_value else {
            throw AuthServiceError.noTokens
        }
        return .authenticated(session: .next(.init(authToken: token)))
    }
    
    func signInBasic(
        baseURL: URL,
        backend: Backend,
        user: String,
        password: String,
        serverTrustPolicy: ServerTrustPolicy
    ) async throws -> SignInOutcome {
        let builder = RequestBuilder.json(baseURL: baseURL, encoder: JSONEncoder())
        
        let client = HTTPClient(
            serverTrustPolicy: serverTrustPolicy,
            interceptor: FixedAuthInterceptor(authorization: .basic(.init(user: user, password: password))),
            logger: logger ?? NoopURLSessionTaskLogger()
        )
        
        let request = switch backend {
        case .intl:
            IntlApi.test()
        case .nextLegacy:
            NextApi.test()
        default:
            throw AuthServiceError.unsupportedBackend
        }
        
        _ = try await client.send(request, with: builder)
        return .authenticated(session: nil)
    }
}
