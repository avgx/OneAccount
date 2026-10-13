import Foundation
import HTTP
import Testing
@testable import OneAccount

private final class CallCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

private final class StubBearerTokenProvider: BearerTokenProvider, @unchecked Sendable {
    var refreshError: Error?

    func validToken() async throws -> String { "token" }

    func refreshToken() async throws {
        if let refreshError { throw refreshError }
    }
}

private func httpError(status: Int) -> HTTPError {
    HTTPError.unacceptableStatusCode(
        statusCode: status,
        body: Data(),
        url: URL(string: "https://example.test/probe")
    )
}

@Test func basicAuthInterceptor_401_rejectsWithoutRetry() async {
    let calls = CallCount()
    let interceptor = BasicAuthInterceptor(user: "user", password: "secret") {
        calls.increment()
    }
    let retry = await interceptor.retry(URLRequest(url: URL(string: "https://example.test")!), dueTo: httpError(status: 401))
    #expect(retry == false)
    #expect(calls.value == 1)
}

@Test func basicAuthInterceptor_500_retriesWithoutRejection() async {
    let calls = CallCount()
    let interceptor = BasicAuthInterceptor(user: "user", password: "secret") {
        calls.increment()
    }
    let retry = await interceptor.retry(URLRequest(url: URL(string: "https://example.test")!), dueTo: httpError(status: 502))
    #expect(retry == true)
    #expect(calls.value == 0)
}

@Test func authInterceptor_rejectionCallsRefreshFailed() async {
    let provider = StubBearerTokenProvider()
    provider.refreshError = URLError(.userAuthenticationRequired)
    let calls = CallCount()
    let interceptor = AuthInterceptor(bearerTokenProvider: provider) {
        calls.increment()
    }
    let retry = await interceptor.retry(URLRequest(url: URL(string: "https://example.test")!), dueTo: httpError(status: 401))
    #expect(retry == false)
    #expect(calls.value == 1)
}

@Test func authInterceptor_timeoutDoesNotPromptRelogin() async {
    let provider = StubBearerTokenProvider()
    provider.refreshError = URLError(.timedOut)
    let calls = CallCount()
    let interceptor = AuthInterceptor(bearerTokenProvider: provider) {
        calls.increment()
    }
    let retry = await interceptor.retry(URLRequest(url: URL(string: "https://example.test")!), dueTo: httpError(status: 401))
    #expect(retry == false)
    #expect(calls.value == 0)
}

@Test func authRejection_nextPasswordCodes() {
    #expect(AuthRejection.isRejection(
        AuthServiceError.nextAuthRejected(code: .AUTHENTICATE_CODE_WRONG_CREDENTIALS, detail: nil)
    ))
    #expect(AuthRejection.isRejection(
        AuthServiceError.nextAuthRejected(code: .AUTHENTICATE_CODE_PASSWORD_INVALID, detail: nil)
    ))
    #expect(AuthRejection.isRejection(
        AuthServiceError.nextAuthRejected(code: .AUTHENTICATE_CODE_USER_LOCKED, detail: nil)
    ))
    #expect(!AuthRejection.isRejection(
        AuthServiceError.nextAuthRejected(code: .AUTHENTICATE_CODE_GENERAL_ERROR, detail: "limit")
    ))
    #expect(!AuthRejection.isRejection(AuthServiceError.nextSecondFactorRequired))
    #expect(AuthRejection.isRejection(URLError(.userAuthenticationRequired)))
    #expect(AuthRejection.isRejection(httpError(status: 401)))
    #expect(!AuthRejection.isRejection(URLError(.timedOut)))
}
