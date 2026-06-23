import Foundation
import Testing
@testable import OneAccount
@testable import OneAccountUI

/// Holds flow state while ``signInAndAdvanceThroughOtpIfNeeded()`` runs (OTP retry loop).
private enum CloudTotpWizardScratch {
    nonisolated(unsafe) static var flow: AccountCreationFlow!
    nonisolated(unsafe) static var totpSecretB32: String?
    nonisolated(unsafe) static var profile: WizardIntegrationProfile!

    @MainActor
    static func signInAndAdvanceThroughOtpIfNeeded() async throws {
        let flow = Self.flow!
        let profile = Self.profile!
        let totpSecretB32 = Self.totpSecretB32

        try await flow.signIn()
        #expect(flow.credentialsState.signInOutcomeKnown)
        if profile == .cloudTotp {
            #expect(flow.credentialsState.needsOtp)
        }
        if flow.credentialsState.needsOtp {
            guard let secret = totpSecretB32 else {
                Issue.record("TOTP secret missing for OTP step.")
                return
            }
            #expect(flow.step == .otp)
            flow.otpState.isTotp = true
            var verified = false
            var lastOtpError: Error?
            for _ in 0..<5 {
                guard let code = totpCode(secretBase32: secret) else { break }
                flow.otpState.code = code
                do {
                    try await flow.verifyOtp()
                    verified = true
                    break
                } catch {
                    lastOtpError = error
                    try await Task.sleep(nanoseconds: 400_000_000)
                }
            }
            if !verified {
                throw lastOtpError ?? AuthServiceError.invalidResponse
            }
        }
    }
}

private enum WizardIntegrationProfile {
    case next
    case intl
    case nextLegacy
    case cloud
    case cloudTotp

    var backend: Backend {
        switch self {
        case .next: .next
        case .intl: .intl
        case .nextLegacy: .nextLegacy
        case .cloud, .cloudTotp: .cloud
        }
    }
}

/// Headless wizard: endpoint is taken from env (URL + profile backend), no network discovery.
@MainActor
private func runAddAccountWizardHeadlessNetwork(
    profile: WizardIntegrationProfile,
    urlString: String,
    user: String,
    password: String,
    totpSecretB32: String?,
    clientIdPrefix: String
) async throws {
    guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        Issue.record("Invalid URL in test configuration.")
        return
    }

    let clientId = "\(clientIdPrefix).\(UUID().uuidString)"
    let auth = AuthService(clientId: clientId) { _ in
        throw AuthServiceError.unsupportedBackend
    }
    let flow = AccountCreationFlow(
        mode: .free,
        useCases: AccountCreationUseCases(authService: auth)
    )

    #expect(flow.step == .endpoint)
    flow.endpointState.urlText = urlString

    await flow.selectDiscoveryRow(DiscoveryRowSelection(
        candidate: DiscoveryCandidate(
            endpoint: Endpoint(url: url, backend: profile.backend),
            name: "",
            summary: ""
        )
    ))

    if flow.step == .serverCertificates {
        await flow.reloadCertificates()
        flow.continueAfterCertificates()
    }

    #expect(flow.step == .credentials)

    flow.draft.user = user
    flow.draft.password = password

    CloudTotpWizardScratch.flow = flow
    CloudTotpWizardScratch.totpSecretB32 = totpSecretB32
    CloudTotpWizardScratch.profile = profile
    defer {
        CloudTotpWizardScratch.flow = nil
        CloudTotpWizardScratch.totpSecretB32 = nil
        CloudTotpWizardScratch.profile = nil
    }

    do {
        try await CloudTotpWizardScratch.signInAndAdvanceThroughOtpIfNeeded()
    } catch {
        if (profile == .cloud || profile == .cloudTotp), AuthServiceError.isCloudConcurrentSessionLimitExceeded(error) {
            return
        }
        throw error
    }

    #expect(flow.step == .done)

    guard let record = AccountRecord(draft: flow.draft) else {
        Issue.record("AccountRecord(draft:) returned nil after wizard.")
        return
    }

    let store = AccountStorage.memory.makeStore()
    try await store.save(record)
    #expect(try await store.exists(record.id))

    switch record.backend {
    case .some(.intl), .some(.nextLegacy):
        #expect(record.auth == .basic)
        #expect(record.session == nil)
    case .some(.next), .some(.cloud):
        #expect(record.session != nil, "Bearer session expected for backend \(String(describing: record.backend)).")
    case .none:
        Issue.record("Record has no backend after wizard.")
    }
}

/// Requires: `CLIENT_ID_PREFIX`, `NEXT_URL`, `NEXT_USER`, `NEXT_PASSWORD` (canonical Next base URL in env).
@Test @MainActor
func addAccountWizard_headlessNetwork_next() async throws {
    let env = DotEnv.merged
    guard let prefix = env["CLIENT_ID_PREFIX"], !prefix.isEmpty else {
        Issue.record("Set CLIENT_ID_PREFIX in .env or environment.")
        return
    }
    guard let urlString = env["NEXT_URL"], !urlString.isEmpty,
          let user = env["NEXT_USER"], !user.isEmpty,
          let password = env["NEXT_PASSWORD"], !password.isEmpty
    else {
        Issue.record("Set NEXT_URL, NEXT_USER, NEXT_PASSWORD in .env to run this test.")
        return
    }
    try await runAddAccountWizardHeadlessNetwork(
        profile: .next,
        urlString: urlString,
        user: user,
        password: password,
        totpSecretB32: nil,
        clientIdPrefix: prefix
    )
}

/// Requires: `CLIENT_ID_PREFIX`, `INTL_URL`, `INTL_USER`, `INTL_PASSWORD`
@Test @MainActor
func addAccountWizard_headlessNetwork_intl() async throws {
    let env = DotEnv.merged
    guard let prefix = env["CLIENT_ID_PREFIX"], !prefix.isEmpty else {
        Issue.record("Set CLIENT_ID_PREFIX in .env or environment.")
        return
    }
    guard let urlString = env["INTL_URL"], !urlString.isEmpty,
          let user = env["INTL_USER"], !user.isEmpty,
          let password = env["INTL_PASSWORD"], !password.isEmpty
    else {
        Issue.record("Set INTL_URL, INTL_USER, INTL_PASSWORD in .env to run this test.")
        return
    }
    try await runAddAccountWizardHeadlessNetwork(
        profile: .intl,
        urlString: urlString,
        user: user,
        password: password,
        totpSecretB32: nil,
        clientIdPrefix: prefix
    )
}

/// Requires: `CLIENT_ID_PREFIX`, `NEXTLEGACY_URL`, `NEXTLEGACY_USER`, `NEXTLEGACY_PASSWORD`
@Test @MainActor
func addAccountWizard_headlessNetwork_nextLegacy() async throws {
    let env = DotEnv.merged
    guard let prefix = env["CLIENT_ID_PREFIX"], !prefix.isEmpty else {
        Issue.record("Set CLIENT_ID_PREFIX in .env or environment.")
        return
    }
    guard let urlString = env["NEXTLEGACY_URL"], !urlString.isEmpty,
          let user = env["NEXTLEGACY_USER"], !user.isEmpty,
          let password = env["NEXTLEGACY_PASSWORD"], !password.isEmpty
    else {
        Issue.record("Set NEXTLEGACY_URL, NEXTLEGACY_USER, NEXTLEGACY_PASSWORD in .env to run this test.")
        return
    }
    try await runAddAccountWizardHeadlessNetwork(
        profile: .nextLegacy,
        urlString: urlString,
        user: user,
        password: password,
        totpSecretB32: nil,
        clientIdPrefix: prefix
    )
}

/// Requires: `CLIENT_ID_PREFIX`, `CLOUD_URL`, `CLOUD_EMAIL`, `CLOUD_PASSWORD`
@Test @MainActor
func addAccountWizard_headlessNetwork_cloud() async throws {
    let env = DotEnv.merged
    guard let prefix = env["CLIENT_ID_PREFIX"], !prefix.isEmpty else {
        Issue.record("Set CLIENT_ID_PREFIX in .env or environment.")
        return
    }
    guard let urlString = env["CLOUD_URL"], !urlString.isEmpty,
          let user = env["CLOUD_EMAIL"], !user.isEmpty,
          let password = env["CLOUD_PASSWORD"], !password.isEmpty
    else {
        Issue.record("Set CLOUD_URL, CLOUD_EMAIL, CLOUD_PASSWORD in .env to run this test.")
        return
    }
    try await runAddAccountWizardHeadlessNetwork(
        profile: .cloud,
        urlString: urlString,
        user: user,
        password: password,
        totpSecretB32: nil,
        clientIdPrefix: prefix
    )
}

/// Requires: `CLIENT_ID_PREFIX`, `CLOUD_TOTP_URL`, `CLOUD_TOTP_EMAIL`, `CLOUD_TOTP_PASSWORD`, `CLOUD_TOTP_SECRET` (base32)
@Test @MainActor
func addAccountWizard_headlessNetwork_cloudTotp() async throws {
    let env = DotEnv.merged
    guard let prefix = env["CLIENT_ID_PREFIX"], !prefix.isEmpty else {
        Issue.record("Set CLIENT_ID_PREFIX in .env or environment.")
        return
    }
    guard let urlString = env["CLOUD_TOTP_URL"], !urlString.isEmpty,
          let user = env["CLOUD_TOTP_EMAIL"], !user.isEmpty,
          let password = env["CLOUD_TOTP_PASSWORD"], !password.isEmpty
    else {
        Issue.record("Set CLOUD_TOTP_URL, CLOUD_TOTP_EMAIL, CLOUD_TOTP_PASSWORD in .env to run this test.")
        return
    }
    guard let secret = env["CLOUD_TOTP_SECRET"], !secret.isEmpty else {
        Issue.record("Set CLOUD_TOTP_SECRET (base32) for cloud TOTP wizard test.")
        return
    }
    try await runAddAccountWizardHeadlessNetwork(
        profile: .cloudTotp,
        urlString: urlString,
        user: user,
        password: password,
        totpSecretB32: secret,
        clientIdPrefix: prefix
    )
}
