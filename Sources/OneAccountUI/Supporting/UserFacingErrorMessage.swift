import Foundation
import HTTP
import OneAccount
import SSLPinning

enum L10n {
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    static func format(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}

enum UserFacingErrorMessage {
    static func text(for error: Error) -> String {
        if let flowError = error as? AccountCreationFlowError {
            return text(for: flowError)
        }
        if let authError = error as? AuthServiceError {
            return text(for: authError)
        }
        if let discoveryError = error as? WizardEndpointDiscovery.DiscoveryFailure {
            return text(for: discoveryError)
        }
        if let certError = error as? CertificatePreviewFailure {
            return text(for: certError)
        }
        if let httpError = error as? HTTPError {
            return connectionFailureMessage(for: httpError)
        }
        if let urlError = error as? URLError {
            return text(for: urlError)
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return L10n.string("discovery.could-not-connect")
    }

    static func text(for flowFailure: FlowFailure) -> String {
        text(for: flowFailure.error)
    }

    private static func text(for error: AccountCreationFlowError) -> String {
        switch error {
        case .missingResolvedEndpoint:
            L10n.string("error.select-server")
        case .emptyCredentials:
            L10n.string("error.enter-credentials")
        case .emptyOtp:
            L10n.string("error.enter-otp")
        }
    }

    private static func text(for error: AuthServiceError) -> String {
        switch error {
        case .cloudOtpWrong(let values):
            appendOtpValues(to: L10n.string("error.wrong-otp"), values: values)
        case .cloudOtpTooManyFailedAttempts(let values):
            appendOtpValues(to: L10n.string("error.otp-too-many-attempts"), values: values)
        case .cloudTotpInvalidCode(let values):
            appendOtpValues(to: L10n.string("error.wrong-totp"), values: values)
        case .cloudWrongPassword:
            L10n.string("error.wrong-password")
        case .cloudNotAuthenticated:
            L10n.string("error.not-authenticated")
        case .cloudSessionInactive:
            L10n.string("error.session-inactive")
        case .cloudConcurrentSessionLimitExceeded:
            L10n.string("error.concurrent-sessions")
        case .cloudBackendRejected(_, let detail, let values):
            appendOtpValues(to: detail, values: values)
        case .invalidResponse:
            L10n.string("error.invalid-response")
        case .unsupportedBackend:
            L10n.string("error.unsupported-backend")
        case .noTokens:
            L10n.string("error.no-tokens")
        case .nextSecondFactorRequired:
            L10n.string("error.2fa-required")
        case .nextAuthRejected(let code, let detail):
            text(forNextAuthCode: code, detail: detail)
        }
    }

    private static func text(for error: WizardEndpointDiscovery.DiscoveryFailure) -> String {
        switch error {
        case .emptyInput, .noSeeds:
            L10n.string("discovery.enter-address")
        case .unsupportedBackend:
            L10n.string("discovery.server-not-recognized")
        case .disallowedBackend:
            L10n.string("discovery.unsupported-backend")
        case .underlying(let underlying):
            text(for: underlying)
        }
    }

    private static func text(for error: CertificatePreviewFailure) -> String {
        switch error {
        case .missingEndpoint:
            L10n.string("error.select-server")
        case .notHTTPS:
            L10n.string("error.cert-preview-https-only")
        case .noCertificates(let host):
            L10n.format("error.cert-no-chain", host)
        case .handshakeFailed(let description):
            L10n.format("error.tls-handshake-failed", description)
        case .invalidServerTrust(let host):
            UserFacingErrorMessage.text(for: SSLPinningError.invalidServerTrust(host: host))
        case .systemTrustFailed(let description):
            description
        }
    }

    private static func text(for urlError: URLError) -> String {
        switch urlError.code {
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return L10n.string("discovery.cannot-reach")
        case .timedOut:
            return L10n.string("discovery.timeout")
        case .notConnectedToInternet, .networkConnectionLost:
            return L10n.string("discovery.no-internet")
        case .userAuthenticationRequired:
            return HTTPURLResponse.localizedString(forStatusCode: 401)
        default:
            return urlError.localizedDescription
        }
    }

    private static func connectionFailureMessage(for httpError: HTTPError) -> String {
        switch httpError {
        case .unacceptableStatusCode(let status, _, _):
            if status == 401 {
                return HTTPURLResponse.localizedString(forStatusCode: 401)
            }
            return text(for: httpError)
        }
    }

    private static func text(forNextAuthCode code: EAuthenticateCode?, detail: String?) -> String {
        if let detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return detail
        }
        switch code {
        case .none:
            return L10n.string("error.sign-in-failed")
        case .AUTHENTICATE_CODE_OK:
            return L10n.string("error.signed-in")
        case .AUTHENTICATE_CODE_WRONG_CREDENTIALS, .AUTHENTICATE_CODE_PASSWORD_INVALID:
            return L10n.string("error.invalid-credentials")
        case .AUTHENTICATE_CODE_USER_LOCKED:
            return L10n.string("error.account-locked")
        case .AUTHENTICATE_CODE_IP_BLOCKED:
            return L10n.string("error.ip-blocked")
        case .AUTHENTICATE_CODE_ALREADY_LOGGED:
            return L10n.string("error.already-logged-in")
        case .AUTHENTICATE_CODE_WRONG_SUPERVISOR_ROLE:
            return L10n.string("error.insufficient-role")
        case .AUTHENTICATE_CODE_TIMEZONE_DENIED:
            return L10n.string("error.timezone-denied")
        case .AUTHENTICATE_CODE_SECOND_FACTOR_AUTH_NEEDED:
            return L10n.string("error.2fa-required")
        case .AUTHENTICATE_CODE_TFA_WRONG_CODE:
            return L10n.string("error.2fa-wrong-code")
        case .AUTHENTICATE_CODE_TFA_NOT_ENABLED:
            return L10n.string("error.2fa-not-enabled")
        case .AUTHENTICATE_CODE_TFA_TYPE_MISMATCH, .AUTHENTICATE_CODE_TFA_TYPE_UNSUPPORTED:
            return L10n.string("error.2fa-unsupported-method")
        case .AUTHENTICATE_CODE_TFA_ATTEMPT_LIMIT_EXCEEDED:
            return L10n.string("error.2fa-too-many-attempts")
        case .AUTHENTICATE_CODE_TFA_TIME_EXCEEDED:
            return L10n.string("error.2fa-timeout")
        case .AUTHENTICATE_CODE_GENERAL_ERROR:
            return L10n.string("error.sign-in-failed")
        }
    }

    private static func appendOtpValues(to base: String, values: OtpErrorValue?) -> String {
        guard let values else { return base }
        var parts: [String] = []
        if let left = values.attemptsLeft {
            parts.append(L10n.format("error.attempts-left", Int64(left)))
        }
        if let sec = values.retryAfterSeconds, sec > 0 {
            parts.append(L10n.format("error.retry-after-seconds", Int64(sec)))
        }
        guard !parts.isEmpty else { return base }
        return [base, parts.joined(separator: " ")].joined(separator: " ")
    }
}
