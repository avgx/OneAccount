import Foundation

public struct AuthV3: Codable, Sendable {
    public let accessToken: String?
    public let refreshToken: String?
    public let warning: String?
    
    public let code: Int?
    public let description: String?
    public let key: String?
    public let message: String?
    public let inner: InnerError?
    
    public let needOTPCheck: Bool?
    public let enabledOTP: Bool?                //from email
    public let activatedTOTP: Bool?
    public let totpEnabledProviders: [String]?  //["microsoft"] OTP code from Microsoft Authenticator app
}

public struct CloudObjectResponse<T: Codable>: Codable {
    public let result: String
    public let statusCode: Int
    public let messageKey: String?
    public let messageDescription: String?
    public let countInPage: Int?
    public let totalCount: Int?
    
    public let resultObject: T?
}

public struct CloudArrayResponse<T: Codable>: Codable {
    public let result: String
    public let statusCode: Int
    public let messageKey: String?
    public let messageDescription: String?
    public let countInPage: Int?
    public let totalCount: Int?
    
    public let resultObject: [T]
}

public struct CloudErrorResponse<T: Codable>: Codable {
    public let code: Int?
    public let description: String?
    public let key: String?
    public let message: String?
    public let inner: InnerError?
    
    public let values: T
}
