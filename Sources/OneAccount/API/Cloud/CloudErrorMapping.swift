import Foundation
import HTTP

public enum CloudErrorMapping: Sendable {
    public static let knownServerKeys: Set<String> = [
        "error.otp.wrong",
        "error.otp.too.many.failed.attempts",
        "error.totp.invalid.code",
        "error.wrong.password",
        "error.not.authenticated",
        "error.session.is.inactive",
        "error.number.of.connection.user.sessions.exceeded",
    ]

    public static func authServiceError(from httpError: HTTPError) -> AuthServiceError {
        switch httpError {
        case .unacceptableStatusCode(let status, let body, _):
            authServiceError(statusCode: status, body: body)
        }
    }

    public static func authServiceError(statusCode: Int, body: Data) -> AuthServiceError {
        if let decoded = try? JSONDecoder().decode(CloudErrorBody.self, from: body) {
            return authServiceError(response: decoded, httpStatus: statusCode)
        }
        let preview = String(data: body.prefix(512), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let detail = preview.isEmpty ? "HTTP \(statusCode)" : preview
        return .cloudBackendRejected(key: nil, detail: detail, values: nil)
    }

    public static func authServiceError(response body: CloudErrorBody, httpStatus: Int) -> AuthServiceError {
        let key = body.key.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        let desc = body.description.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        let msg = body.message.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }

        let discriminator: String? = {
            if let key { return key }
            if let desc, knownServerKeys.contains(desc) { return desc }
            return nil
        }()

        switch discriminator {
        case "error.otp.wrong":
            return .cloudOtpWrong(values: body.values)
        case "error.otp.too.many.failed.attempts":
            return .cloudOtpTooManyFailedAttempts(values: body.values)
        case "error.totp.invalid.code":
            return .cloudTotpInvalidCode(values: body.values)
        case "error.wrong.password":
            return .cloudWrongPassword
        case "error.not.authenticated":
            return .cloudNotAuthenticated
        case "error.session.is.inactive":
            return .cloudSessionInactive
        case "error.number.of.connection.user.sessions.exceeded":
            return .cloudConcurrentSessionLimitExceeded
        default:
            let detail = desc ?? msg ?? key ?? "HTTP \(httpStatus)"
            return .cloudBackendRejected(key: key, detail: detail, values: body.values)
        }
    }
}

enum CloudErrorMessage: Sendable {
    static func userText(for error: AuthServiceError) -> String? {
        switch error {
        case .cloudOtpWrong(let values):
            basePlusValues(base: "Wrong OTP code.", values: values)
        case .cloudOtpTooManyFailedAttempts(let values):
            basePlusValues(base: "Too many wrong OTP attempts.", values: values)
        case .cloudTotpInvalidCode(let values):
            basePlusValues(base: "Wrong authenticator (TOTP) code.", values: values)
        case .cloudWrongPassword:
            "Wrong email or password."
        case .cloudNotAuthenticated:
            "Not authenticated."
        case .cloudSessionInactive:
            "Session is inactive. Sign in again."
        case .cloudConcurrentSessionLimitExceeded:
            "Too many active Cloud sessions for this account. Sign out elsewhere or try again later."
        case .cloudBackendRejected(_, let detail, let values):
            basePlusValues(base: detail, values: values)
        default:
            nil
        }
    }

    private static func basePlusValues(base: String, values: OtpErrorValue?) -> String {
        appendValuesSuffix(to: base, values: values)
    }

    private static func appendValuesSuffix(to base: String, values: OtpErrorValue?) -> String {
        guard let values else { return base }
        var parts: [String] = []
        if let left = values.attemptsLeft {
            parts.append("Attempts left: \(left).")
        }
        if let sec = values.retryAfterSeconds, sec > 0 {
            parts.append("Retry after \(sec) s.")
        }
        guard !parts.isEmpty else { return base }
        return [base, parts.joined(separator: " ")].joined(separator: " ")
    }
}
