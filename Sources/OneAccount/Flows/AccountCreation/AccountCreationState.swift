import Foundation
import SSLPinning

public struct EndpointInputState: Equatable, Sendable {
    public var isResolving = false
    public var message: String?

    public init(isResolving: Bool = false, message: String? = nil) {
        self.isResolving = isResolving
        self.message = message
    }
}

public struct CredentialsState: Equatable, Sendable {
    public var isSigningIn = false
    public var message: String?
    public var signInOutcomeKnown = false
    public var needsOtp = false
    public var otpCanTotp = true

    public init(
        isSigningIn: Bool = false,
        message: String? = nil,
        signInOutcomeKnown: Bool = false,
        needsOtp: Bool = false,
        otpCanTotp: Bool = true
    ) {
        self.isSigningIn = isSigningIn
        self.message = message
        self.signInOutcomeKnown = signInOutcomeKnown
        self.needsOtp = needsOtp
        self.otpCanTotp = otpCanTotp
    }
}

public struct OTPState: Equatable, Sendable {
    public var code = ""
    public var isTotp = false
    public var canTotp = true
    public var isVerifying = false
    public var message: String?

    public init(
        code: String = "",
        isTotp: Bool = false,
        canTotp: Bool = true,
        isVerifying: Bool = false,
        message: String? = nil
    ) {
        self.code = code
        self.isTotp = isTotp
        self.canTotp = canTotp
        self.isVerifying = isVerifying
        self.message = message
    }
}

public struct CertificatePreviewState: Equatable, Sendable {
    public var isLoading = false
    public var chain: [CertificateInfo] = []
    public var message: String?

    public init(
        isLoading: Bool = false,
        chain: [CertificateInfo] = [],
        message: String? = nil
    ) {
        self.isLoading = isLoading
        self.chain = chain
        self.message = message
    }
}

public struct ResolvedEndpoint: Equatable, Sendable {
    public var url: URL
    public var backend: Backend

    public init(url: URL, backend: Backend) {
        self.url = url
        self.backend = backend
    }
}

public struct EndpointInput: Equatable, Sendable {
    public var rawURL: String

    public init(rawURL: String) {
        self.rawURL = rawURL
    }
}

public struct AccountCredentialsRequest: Equatable, Sendable {
    public var endpoint: Endpoint
    public var user: String
    public var password: String

    public init(endpoint: Endpoint, user: String, password: String) {
        self.endpoint = endpoint
        self.user = user
        self.password = password
    }
}

public enum AccountSignInOutcome: Equatable, Sendable {
    case authenticated(session: BackendSession?)
    case needsOtp(canTotp: Bool)
}

public struct OTPVerificationRequest: Equatable, Sendable {
    public var endpoint: Endpoint
    public var user: String
    public var code: String
    public var mode: OtpMode

    public init(endpoint: Endpoint, user: String, code: String, mode: OtpMode) {
        self.endpoint = endpoint
        self.user = user
        self.code = code
        self.mode = mode
    }
}
