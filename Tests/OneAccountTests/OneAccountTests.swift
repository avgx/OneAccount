import Foundation
import Testing
import HTTP
import RequestResponse
import JWTDecode
import DebugThings
import Logging
@testable import OneAccount

/// Requires: `NEXT_URL`, `NEXT_USER`, `NEXT_PASSWORD`
/// Request:
/// POST `v1/authentication/authenticate_ex2` with `{"user_name":"...","password":"..."}`
/// Response: 200
/// `{"error_code":"AUTHENTICATE_CODE_OK","token_name":"auth_token","token_value":"...", ...}`
/// Refresh in 5 minutes or faster with `v1/authentication/renew2`
@Test func sampleLoginNext() async throws {
    let env = DotEnv.merged
    guard let urlString = env["NEXT_URL"], !urlString.isEmpty, let url = URL(string: urlString),
          let user = env["NEXT_USER"], !user.isEmpty,
          let password = env["NEXT_PASSWORD"], !password.isEmpty,
          let clientIdPrefix = env["CLIENT_ID_PREFIX"], !clientIdPrefix.isEmpty
    else {
        Issue.record("Set NEXT_URL, NEXT_USER, NEXT_PASSWORD, CLIENT_ID_PREFIX in .env to run this test.")
        return
    }
    DebugThings.bootstrapOSLog(level: .debug)
    let builder = RequestBuilder.json(baseURL: url, encoder: JSONEncoder())
    let authClient = HTTPClient(
        observer: LoggingRequestObserver(logger: Logger(label: "auth")),
        //logger: SimpleURLSessionTaskLogger(label: "login", logReceiveData: true)
    )
    
    let authenticateResult = try await authClient.send(NextApi.authenticate(user: user, password: password), with: builder)
    #expect(authenticateResult.value.error_code == .AUTHENTICATE_CODE_OK)
    #expect(authenticateResult.value.token_name == "auth_token")
    #expect(authenticateResult.value.token_value != nil)
    let jwt = authenticateResult.value.token_value!
    let decoded = try decode(jwt: jwt)
    #expect(decoded.expiresAt != nil)
    #expect(decoded.expiresAt! > Date())
    
    print(authenticateResult.value.token_value ?? "no token")
    
    let auth = Auth(policy: .init(margin: 290), refresher: NextSessionRefresher(baseURL: url))
    await auth.setSession(.next(.init(authToken: jwt)))
    
    let client = HTTPClient(
        configuration: .ephemeral,
        interceptor: AuthInterceptor(auth: auth),
        observer: LoggingRequestObserver(),
        logger: SimpleURLSessionTaskLogger(label: "work", logReceiveData: true)
    )
    
    var i = 0
    while true {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let res = try await client.send(NextApi.test(), with: builder)
            
            print("\(Date()) \(String(describing: res.statusCode))")
            i += 1
            if i > 20 {
                break
            }
        } catch {
            print("\(error) - \(error.localizedDescription)")
        }
    }
    
    _ = try await client.send(NextApi.close(), with: builder)
}

/// Requires: `INTL_URL`, `INTL_USER`, `INTL_PASSWORD`
/// Use Basic auth
@Test func sampleIntl() async throws {
    let env = DotEnv.merged
    guard let urlString = env["INTL_URL"], !urlString.isEmpty, let url = URL(string: urlString),
          let user = env["INTL_USER"], !user.isEmpty,
          let password = env["INTL_PASSWORD"], !password.isEmpty,
          let clientIdPrefix = env["CLIENT_ID_PREFIX"], !clientIdPrefix.isEmpty
    else {
        Issue.record("Set INTL_URL, INTL_USER, INTL_PASSWORD, CLIENT_ID_PREFIX in .env to run this test.")
        return
    }
    DebugThings.bootstrapOSLog(level: .debug)
    let builder = RequestBuilder.json(baseURL: url, encoder: JSONEncoder())
        
    let client = HTTPClient(
        configuration: .ephemeral,
        interceptor: FixedAuthInterceptor(authorization: .basic(.init(user: user, password: password))),
        observer: LoggingRequestObserver(),
        logger: SimpleURLSessionTaskLogger(label: "work", logReceiveData: true)
    )
    
    var i = 0
    while true {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let res = try await client.send(IntlApi.test(), with: builder)
            
            print("\(Date()) \(String(describing: res.statusCode))")
            i += 1
            if i > 10 {
                break
            }
        } catch {
            print("\(error) - \(error.localizedDescription)")
        }
    }
    
}

/// Requires: `NEXTLEGACY_URL`, `NEXTLEGACY_USER`, `NEXTLEGACY_PASSWORD`
/// Use Basic auth
@Test func sampleLegacyNext() async throws {
    let env = DotEnv.merged
    guard let urlString = env["NEXTLEGACY_URL"], !urlString.isEmpty, let url = URL(string: urlString),
          let user = env["NEXTLEGACY_USER"], !user.isEmpty,
          let password = env["NEXTLEGACY_PASSWORD"], !password.isEmpty,
          let clientIdPrefix = env["CLIENT_ID_PREFIX"], !clientIdPrefix.isEmpty
    else {
        Issue.record("Set NEXTLEGACY_URL, NEXTLEGACY_USER, NEXTLEGACY_PASSWORD, CLIENT_ID_PREFIX in .env to run this test.")
        return
    }
    
    DebugThings.bootstrapOSLog(level: .debug)
    let builder = RequestBuilder.json(baseURL: url, encoder: JSONEncoder())
    
    let client = HTTPClient(
        configuration: .ephemeral,
        interceptor: FixedAuthInterceptor(authorization: .basic(.init(user: user, password: password))),
        observer: LoggingRequestObserver(),
        logger: SimpleURLSessionTaskLogger(label: "work", logReceiveData: true)
    )
    
    var i = 0
    while true {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let res = try await client.send(NextApi.test(), with: builder)
            
            print("\(Date()) \(String(describing: res.statusCode))")
            i += 1
            if i > 10 {
                break
            }
        } catch {
            print("\(error) - \(error.localizedDescription)")
        }
    }
    
}

/// Requires: `CLOUD_URL`, `CLOUD_EMAIL`, `CLOUD_PASSWORD`
/// Request:
/// POST `api/v3/ac-backend/users/login` with `{"email":"...","password":"...","clientId":"..."}`
/// Response: 200
/// `{"accessToken":"...","refreshToken":"..."}`
@Test func sampleLoginCloudNoOTP() async throws {
    let env = DotEnv.merged
    guard let urlString = env["CLOUD_URL"], !urlString.isEmpty, let url = URL(string: urlString),
          let email = env["CLOUD_EMAIL"], !email.isEmpty,
          let password = env["CLOUD_PASSWORD"], !password.isEmpty,
          let clientIdPrefix = env["CLIENT_ID_PREFIX"], !clientIdPrefix.isEmpty
    else {
        Issue.record("Set CLOUD_URL, CLOUD_EMAIL, CLOUD_PASSWORD, CLIENT_ID_PREFIX in .env to run this test.")
        return
    }
    
    DebugThings.bootstrapOSLog(level: .debug)
    let clientId = "\(clientIdPrefix).\(UUID().uuidString)"
    let builder = RequestBuilder.json(baseURL: url, encoder: JSONEncoder())
    let authClient = HTTPClient(
        observer: LoggingRequestObserver(),
        logger: SimpleURLSessionTaskLogger(label: "login", logReceiveData: true)
    )
    
    let loginResult = try await authClient.send(
        CloudApi.login(
            .init(
                email: email,
                password: password,
                locale: Locale.current.identifier,
                clientId: clientId
            )
        ),
        with: builder
    )
    #expect(loginResult.value.accessToken != nil)
    #expect(loginResult.value.refreshToken != nil)
    let jwt = loginResult.value.accessToken!
    let rjwt = loginResult.value.refreshToken!
    let decoded = try decode(jwt: jwt)
    #expect(decoded.expiresAt != nil)
    #expect(decoded.expiresAt! > Date())
    #expect(decoded.issuer == "Cloud")
    #expect(decoded.claim(name: "Type").string == "accessToken")
    
    let auth = Auth(policy: .init(margin: 24*3600.0 - 10.0), refresher: CloudSessionRefresher(baseURL: url))

    await auth.setSession(.cloud(.init(accessToken: jwt, refreshToken: rjwt)))
    
    let client = HTTPClient(
        configuration: .ephemeral,
        interceptor: AuthInterceptor(auth: auth),
        observer: LoggingRequestObserver(),
        logger: SimpleURLSessionTaskLogger(label: "work", logReceiveData: true)
    )
    
    var i = 0
    while true {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let res = try await client.send(CloudApi.test(), with: builder)
            
            print("\(Date()) \(String(describing: res.statusCode))")
            i += 1
            if i > 30 {
                break
            }
        } catch {
            print("\(error) - \(error.localizedDescription)")
        }
    }
    
}

/// Requires: `CLOUD_TOTP_URL`, `CLOUD_TOTP_EMAIL`, `CLOUD_TOTP_PASSWORD`, `CLOUD_TOTP_SECRET` (base32 from authenticator).
/// Request:
/// POST `api/v3/ac-backend/users/login` with `{"email":"...","password":"...","clientId":"..."}`
/// Response: 200
/// `{"activatedTOTP":true,"enabledOTP":true,"needOTPCheck":true,"totpEnabledProviders":["microsoft"]}`
/// Request:
/// PATCH `api/v3/ac-backend/users/totp` with `{"provider":"microsoft","email":"...","totp":"...","clientId":"..."}`
/// Response: 200
/// `{"accessToken":"...","refreshToken":"..."}`
@Test func sampleLoginCloudTOTP() async throws {
    let env = DotEnv.merged
    guard let urlString = env["CLOUD_TOTP_URL"], !urlString.isEmpty, let url = URL(string: urlString),
          let email = env["CLOUD_TOTP_EMAIL"], !email.isEmpty,
          let password = env["CLOUD_TOTP_PASSWORD"], !password.isEmpty,
          let secretB32 = env["CLOUD_TOTP_SECRET"], !secretB32.isEmpty,
          let clientIdPrefix = env["CLIENT_ID_PREFIX"], !clientIdPrefix.isEmpty
    else {
        Issue.record("Set CLOUD_TOTP_URL, CLOUD_TOTP_EMAIL, CLOUD_TOTP_PASSWORD, CLOUD_TOTP_SECRET, CLIENT_ID_PREFIX in .env to run this test.")
        return
    }

    do {
        DebugThings.bootstrapOSLog(level: .debug)
        let builder = RequestBuilder.json(baseURL: url, encoder: JSONEncoder())
        let authClient = HTTPClient(
            observer: LoggingRequestObserver(),
            logger: SimpleURLSessionTaskLogger(label: "login", logReceiveData: true)
        )

        let clientId = "\(clientIdPrefix).\(UUID().uuidString)"
        let loginResult = try await authClient.send(
            CloudApi.login(.init(email: email, password: password, locale: Locale.current.identifier, clientId: clientId)),
            with: builder
        )
        #expect(loginResult.value.needOTPCheck == true)
        #expect(loginResult.value.totpEnabledProviders?.contains("microsoft") == true)
        #expect(loginResult.value.accessToken == nil)
        #expect(loginResult.value.refreshToken == nil)

        guard let totp = totpCode(secretBase32: secretB32) else {
            Issue.record("TOTP generation failed (check CLOUD_TOTP_SECRET base32).")
            return
        }

        let verifyResult = try await authClient.send(
            CloudApi.totpVerify(.init(email: email, totp: totp, clientId: clientId)),
            with: builder
        )
        #expect(verifyResult.value.accessToken != nil)
        #expect(verifyResult.value.refreshToken != nil)
        let jwt = verifyResult.value.accessToken!
        let rjwt = verifyResult.value.refreshToken!
        let decoded = try decode(jwt: jwt)
        #expect(decoded.expiresAt != nil)
        #expect(decoded.expiresAt! > Date())
        #expect(decoded.issuer == "Cloud")
        #expect(decoded.claim(name: "Type").string == "accessToken")

        let auth = Auth(policy: .init(margin: 24 * 3600.0 - 30.0), refresher: CloudSessionRefresher(baseURL: url))
//    let auth = Auth(policy: .init(margin: 24 * 3600.0 - 30.0)) { currentSession in
//        guard case .cloud(let session) = currentSession else {
//            throw URLError(.userAuthenticationRequired)
//        }
//        let debugRefreshToken = try decode(jwt: session.refreshToken)
//        #expect(debugRefreshToken.expiresAt! > Date())
//        #expect(debugRefreshToken.issuer == "Cloud")
//        #expect(debugRefreshToken.claim(name: "Type").string == "refreshToken")
//        let renewClient = HTTPClient(
//            interceptor: FixedTokenInterceptor(token: session.refreshToken),
//            observer: LoggingRequestObserver(),
//            logger: SimpleURLSessionTaskLogger(label: "auth", logReceiveData: true)
//        )
//        let renewResult = try await renewClient.send(CloudApi.refreshTokens(), with: builder)
//        guard let accessToken = renewResult.value.accessToken, let refreshToken = renewResult.value.refreshToken else {
//            throw URLError(.userAuthenticationRequired)
//        }
//        return .cloud(.init(accessToken: accessToken, refreshToken: refreshToken))
//    }
        await auth.setSession(.cloud(.init(accessToken: jwt, refreshToken: rjwt)))

        let client = HTTPClient(
            configuration: .ephemeral,
            interceptor: AuthInterceptor(auth: auth),
            observer: LoggingRequestObserver(),
            logger: SimpleURLSessionTaskLogger(label: "work", logReceiveData: true)
        )
        _ = try await client.send(CloudApi.test(), with: builder)

        _ = try await client.send(CloudApi.logout(), with: builder)
    } catch {
        if let http = error as? HTTPError {
            let mapped = CloudErrorMapping.authServiceError(from: http)
            if AuthServiceError.isCloudConcurrentSessionLimitExceeded(mapped) { return }
        }
        if AuthServiceError.isCloudConcurrentSessionLimitExceeded(error) { return }
        throw error
    }
}
