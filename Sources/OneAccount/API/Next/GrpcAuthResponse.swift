import Foundation

struct GrpcAuthResponse: Codable, Sendable {
    let token_name: String?
    let token_value: String?
    let expires_at: String?
    let is_unrestricted: Bool?
    let user_id: String?
    let roles_ids: [String]?
    
    let credential_traits: CredentialTraits?
    
    let error_code: EAuthenticateCode?
    let error_description: AuthenticateGeneralErrorDescription?
}

struct AuthenticateGeneralErrorDescription: Codable, Sendable {
    let description: String?
    let reached_connection_limit: Bool?
    let incorrect_client_type: Bool?
}

struct CredentialTraits: Codable, Sendable {
    let password_expires_in: String
    let password_expires_soon: Bool
    let password_must_be_changed: Bool
}

public enum EAuthenticateCode: String, Codable, Sendable {
    case AUTHENTICATE_CODE_OK
    case AUTHENTICATE_CODE_GENERAL_ERROR
    case AUTHENTICATE_CODE_WRONG_CREDENTIALS
    case AUTHENTICATE_CODE_USER_LOCKED
    case AUTHENTICATE_CODE_IP_BLOCKED
    case AUTHENTICATE_CODE_ALREADY_LOGGED
    case AUTHENTICATE_CODE_PASSWORD_INVALID
    case AUTHENTICATE_CODE_WRONG_SUPERVISOR_ROLE
    case AUTHENTICATE_CODE_TIMEZONE_DENIED
    case AUTHENTICATE_CODE_SECOND_FACTOR_AUTH_NEEDED
    case AUTHENTICATE_CODE_TFA_WRONG_CODE
    case AUTHENTICATE_CODE_TFA_NOT_ENABLED
    case AUTHENTICATE_CODE_TFA_TYPE_MISMATCH
    case AUTHENTICATE_CODE_TFA_TYPE_UNSUPPORTED
    case AUTHENTICATE_CODE_TFA_ATTEMPT_LIMIT_EXCEEDED
    case AUTHENTICATE_CODE_TFA_TIME_EXCEEDED
}

struct CloseSessionResponse: Codable, Sendable {
    enum EErrorCode: String, Codable, Sendable {
        case OK
        case GENERAL_ERROR
        case IP_BLOCKED
    }
    let error_code: EErrorCode
}
