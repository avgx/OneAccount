import Foundation
import Testing
@testable import OneAccount

@Suite("Cloud OTP/TOTP error mapping")
struct CloudErrorMappingTests {

    @Test func mapsTotpInvalidCode() throws {
        let json = #"{"code":400,"description":"totp invalid code","key":"error.totp.invalid.code"}"#
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 400)
        guard case .cloudTotpInvalidCode(let values) = err else {
            Issue.record("Expected cloudTotpInvalidCode, got \(err)")
            return
        }
        #expect(values == nil)
        let text = err.errorDescription ?? ""
        #expect(text.contains("authenticator"))
    }

    @Test func mapsWrongPassword() throws {
        let json = #"{"description":"wrong password","key":"error.wrong.password"}"#
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 401)
        guard case .cloudWrongPassword = err else {
            Issue.record("Expected cloudWrongPassword")
            return
        }
        let text = err.errorDescription ?? ""
        #expect(text.contains("password"))
    }

    @Test func mapsOtpWrongWithAttemptsSuffix() throws {
        let json = """
        {"description":"error.otp.wrong","key":"error.otp.wrong","inner":null,"values":{"otpLoginAttemptsLeft":"2","otpLoginRetryAfterSec":"0"}}
        """
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 400)
        guard case .cloudOtpWrong(let values) = err else {
            Issue.record("Expected cloudOtpWrong")
            return
        }
        #expect(values?.attemptsLeft == 2)
        #expect(values?.retryAfterSeconds == 0)
        let text = err.errorDescription ?? ""
        #expect(text.contains("OTP"))
        #expect(text.contains("2"))
    }

    @Test func mapsOtpTooManyWithRetrySuffix() throws {
        let json = """
        {"description":"error.otp.too.many.failed.attempts","key":"error.otp.too.many.failed.attempts","inner":null,"values":{"otpLoginAttemptsLeft":"0","otpLoginRetryAfterSec":"600"}}
        """
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 400)
        guard case .cloudOtpTooManyFailedAttempts = err else {
            Issue.record("Expected cloudOtpTooManyFailedAttempts")
            return
        }
        let text = err.errorDescription ?? ""
        #expect(text.contains("OTP"))
        #expect(text.contains("600"))
    }

    @Test func mapsNotAuthenticated() throws {
        let json = #"{"description":"not authenticated","key":"error.not.authenticated"}"#
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 401)
        guard case .cloudNotAuthenticated = err else {
            Issue.record("Expected cloudNotAuthenticated")
            return
        }
        #expect((err.errorDescription ?? "").contains("authenticated"))
    }

    @Test func mapsSessionInactive() throws {
        let json = #"{"key":"error.session.is.inactive","description":"error.session.is.inactive"}"#
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 401)
        guard case .cloudSessionInactive = err else {
            Issue.record("Expected cloudSessionInactive")
            return
        }
        #expect((err.errorDescription ?? "").localizedCaseInsensitiveContains("session"))
    }

    @Test func mapsConcurrentSessionLimitExceeded() throws {
        let json = #"{"key":"error.number.of.connection.user.sessions.exceeded","description":"error.number.of.connection.user.sessions.exceeded"}"#
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 403)
        guard case .cloudConcurrentSessionLimitExceeded = err else {
            Issue.record("Expected cloudConcurrentSessionLimitExceeded")
            return
        }
        #expect(AuthServiceError.isCloudConcurrentSessionLimitExceeded(err))
        #expect((err.errorDescription ?? "").localizedCaseInsensitiveContains("session"))
    }

    @Test func discriminatorUsesDescriptionWhenKeyMissing() throws {
        let json = #"{"description":"error.totp.invalid.code"}"#
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 400)
        guard case .cloudTotpInvalidCode = err else {
            Issue.record("Expected cloudTotpInvalidCode when only description matches known key")
            return
        }
    }

    @Test func unknownKeyFallsBackToBackendRejected() throws {
        let json = #"{"key":"error.unknown.future","description":"Something went wrong"}"#
        let body = try JSONDecoder().decode(CloudErrorBody.self, from: Data(json.utf8))
        let err = CloudErrorMapping.authServiceError(response: body, httpStatus: 400)
        guard case .cloudBackendRejected(let key, let detail, _) = err else {
            Issue.record("Expected cloudBackendRejected")
            return
        }
        #expect(key == "error.unknown.future")
        #expect(detail == "Something went wrong")
    }

    @Test func nonJsonBodyMapsToRejectedWithPreview() {
        let data = Data("not json".utf8)
        let err = CloudErrorMapping.authServiceError(statusCode: 502, body: data)
        guard case .cloudBackendRejected(_, let detail, _) = err else {
            Issue.record("Expected cloudBackendRejected")
            return
        }
        #expect(detail == "not json")
    }
}
