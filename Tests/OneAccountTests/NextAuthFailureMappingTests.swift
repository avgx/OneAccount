import Foundation
import Testing
@testable import OneAccount

@Test func nextAuthFailure_secondFactor_mapsToDedicatedError() throws {
    let json = """
    {"error_code":"AUTHENTICATE_CODE_SECOND_FACTOR_AUTH_NEEDED","token_value":null}
    """
    let response = try JSONDecoder().decode(GrpcAuthResponse.self, from: Data(json.utf8))
    let error = NextAuthFailureMapping.authServiceError(response: response)
    guard case .nextSecondFactorRequired = error else {
        Issue.record("expected nextSecondFactorRequired, got \(error)")
        return
    }
    #expect(error.errorDescription?.contains("Two-factor") == true)
}

@Test func nextAuthFailure_wrongCredentials_message() throws {
    let json = """
    {"error_code":"AUTHENTICATE_CODE_WRONG_CREDENTIALS","token_value":null}
    """
    let response = try JSONDecoder().decode(GrpcAuthResponse.self, from: Data(json.utf8))
    let error = NextAuthFailureMapping.authServiceError(response: response)
    guard case .nextAuthRejected(let code, let detail) = error else {
        Issue.record("expected nextAuthRejected")
        return
    }
    #expect(code == .AUTHENTICATE_CODE_WRONG_CREDENTIALS)
    #expect(detail == nil)
    #expect(error.errorDescription?.contains("Invalid") == true)
}

@Test func nextAuthFailure_connectionLimit_prefersDescription() throws {
    let json = """
    {"error_code":"AUTHENTICATE_CODE_GENERAL_ERROR","token_value":null,"error_description":{"description":"too many","reached_connection_limit":true}}
    """
    let response = try JSONDecoder().decode(GrpcAuthResponse.self, from: Data(json.utf8))
    let error = NextAuthFailureMapping.authServiceError(response: response)
    guard case .nextAuthRejected(_, let detail) = error else {
        Issue.record("expected nextAuthRejected")
        return
    }
    #expect(detail == "too many")
}
