import Combine
import Foundation
import SSLPinning

@MainActor
public final class AccountCreationFlow: ObservableObject {
    @Published public var draft: Draft
    @Published public var step: AccountCreationStep
    @Published public var endpointState = EndpointStepState()
    @Published public var credentialsState = CredentialsState()
    @Published public var otpState = OTPState()
    @Published public var certificatePreview: CertificatePreview = .idle

    public let endpointWizardMode: EndpointWizardMode
    private let useCases: AccountCreationUseCases
    private var pendingDemoSignIn = false
    public var performSave: (() async throws -> Void)?

    public init(
        mode: EndpointWizardMode = .free,
        useCases: AccountCreationUseCases
    ) {
        endpointWizardMode = mode
        self.useCases = useCases

        var initialDraft = Draft()
        switch mode {
        case .free:
            step = .endpoint
        case .locked(let endpoint):
            initialDraft.resolvedEndpoint = endpoint
            initialDraft.serverTrustPolicy = .system
            step = .credentials
        }
        draft = initialDraft
    }

    public var isEndpointLocked: Bool {
        if case .locked = endpointWizardMode { return true }
        return false
    }

    public var canSave: Bool {
        guard step == .done else { return false }
        return draft.resolvedEndpoint != nil
            && !draft.user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.password.isEmpty
    }

    public var wizardTotalSteps: Int {
        let endpointCount = isEndpointLocked ? 0 : 1
        let certificateCount = shouldPreviewCertificates ? 1 : 0
        let otpCount = credentialsState.signInOutcomeKnown && credentialsState.needsOtp ? 1 : 0
        return 2 + endpointCount + certificateCount + otpCount
    }

    public var wizardCurrentStepIndex: Int {
        let ordered = expectedSteps()
        guard let index = ordered.firstIndex(of: step) else { return 1 }
        return index + 1
    }

    public var shouldPreviewCertificates: Bool {
        guard !isEndpointLocked else { return false }
        guard !pendingDemoSignIn else { return false }
        guard let endpoint = draft.resolvedEndpoint else { return false }
        return Self.shouldPreviewCertificates(for: endpoint.url)
    }

    public func prepareDraftForSave() {
        if isEndpointLocked {
            draft.serverTrustPolicy = .system
        }
    }

    public func resetCredentialState() {
        credentialsState.failure = nil
        credentialsState.signInOutcomeKnown = false
        credentialsState.needsOtp = false
        credentialsState.otpCanTotp = true
        otpState = OTPState()
        draft.session = nil
    }

    public func validateDemoCredentials(_ request: AccountCredentialsRequest) async -> Bool {
        var demoRequest = request
        demoRequest.serverTrustPolicy = .system
        do {
            let outcome = try await useCases.validateCredentials(demoRequest)
            if case .authenticated = outcome {
                return true
            }
            return false
        } catch {
            return false
        }
    }

    public func selectDiscoveryRow(_ row: DiscoveryRowSelection) async {
        endpointState.failure = nil
        pendingDemoSignIn = false
        applyDiscoverySelection(candidate: row.candidate, seedURL: row.seedURL)

        if row.isDemo {
            draft.serverTrustPolicy = .system
            pendingDemoSignIn = true
        }

        await transitionAfterEndpointReady()
    }

    public func reloadCertificates(probePolicy: ServerTrustPolicy = .system) async {
        guard let endpoint = draft.resolvedEndpoint else {
            certificatePreview = .failed(.missingEndpoint)
            return
        }
        let preservedTrustStatus = probePolicy == .system ? nil : certificatePreview.trustStatus
        var loaded = await useCases.loadCertificates(
            for: endpoint.asEndpoint,
            serverTrustPolicy: probePolicy,
            current: certificatePreview
        )
        if let preservedTrustStatus {
            loaded = loaded.replacingTrustStatus(preservedTrustStatus)
        }
        certificatePreview = loaded
    }

    public func continueAfterCertificates() {
        guard step == .serverCertificates else { return }
        step = .credentials
        Task { await attemptDemoSignInIfNeeded() }
    }

    public func signIn(serverTrustPolicy: ServerTrustPolicy? = nil) async throws {
        resetCredentialState()
        guard let endpoint = draft.resolvedEndpoint else {
            let error = AccountCreationFlowError.missingResolvedEndpoint
            credentialsState.failure = FlowFailure(error)
            throw error
        }
        let user = draft.user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !draft.password.isEmpty else {
            let error = AccountCreationFlowError.emptyCredentials
            credentialsState.failure = FlowFailure(error)
            throw error
        }

        let policy = serverTrustPolicy ?? (isEndpointLocked ? .system : draft.serverTrustPolicy)

        do {
            let outcome = try await useCases.validateCredentials(
                AccountCredentialsRequest(
                    endpoint: endpoint.asEndpoint,
                    user: user,
                    password: draft.password,
                    serverTrustPolicy: policy
                )
            )
            credentialsState.failure = nil
            credentialsState.signInOutcomeKnown = true
            switch outcome {
            case .authenticated(let session):
                draft.session = session
                credentialsState.needsOtp = false
                step = .done
            case .needsOtp(let canTotp):
                credentialsState.needsOtp = true
                credentialsState.otpCanTotp = canTotp
                otpState.canTotp = canTotp
                step = .otp
            }
        } catch {
            credentialsState.failure = FlowFailure(error)
            credentialsState.signInOutcomeKnown = false
            throw error
        }
    }

    public func verifyOtp() async throws {
        guard let endpoint = draft.resolvedEndpoint else {
            let error = AccountCreationFlowError.missingResolvedEndpoint
            otpState.failure = FlowFailure(error)
            throw error
        }
        let code = otpState.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 4 else {
            let error = AccountCreationFlowError.emptyOtp
            otpState.failure = FlowFailure(error)
            throw error
        }

        otpState.failure = nil

        do {
            let session = try await useCases.verifyOtp(
                OTPVerificationRequest(
                    endpoint: endpoint,
                    user: draft.user.trimmingCharacters(in: .whitespacesAndNewlines),
                    code: code,
                    mode: otpState.isTotp ? .totp : .otp,
                    serverTrustPolicy: isEndpointLocked ? .system : draft.serverTrustPolicy
                )
            )
            draft.session = session
            step = .done
        } catch {
            otpState.failure = FlowFailure(error)
            throw error
        }
    }

    public func clearResolvedEndpointOnURLChange() {
        draft.resolvedEndpoint = nil
        pendingDemoSignIn = false
    }

    private func applyDiscoverySelection(candidate: DiscoveryCandidate, seedURL: URL?) {
        guard let backend = candidate.endpoint.backend else { return }

        if let seedURL {
            var components = URLComponents(url: seedURL, resolvingAgainstBaseURL: false)
            let userPart = components?.user
            let passwordPart = components?.password
            components?.user = nil
            components?.password = nil
            components?.fragment = nil
            if let cleanURL = components?.url {
                endpointState.urlText = cleanURL.absoluteString
            }
            if let userPart, let passwordPart {
                draft.user = userPart
                draft.password = passwordPart
            }
        } else {
            endpointState.urlText = candidate.endpoint.url.absoluteString
        }

        draft.resolvedEndpoint = ResolvedEndpoint(
            url: candidate.endpoint.url.removingCredentials().removingFragment(),
            backend: backend,
            name: candidate.name
        )
        draft.displayName = URLComponents(url: candidate.endpoint.url, resolvingAgainstBaseURL: false)?.fragment ?? ""
    }

    private func transitionAfterEndpointReady() async {
        guard draft.resolvedEndpoint != nil else { return }
        resetCredentialState()

        if shouldPreviewCertificates {
            step = .serverCertificates
            await reloadCertificates()
            return
        }

        step = .credentials
        await attemptDemoSignInIfNeeded()
    }

    private func attemptDemoSignInIfNeeded() async {
        guard pendingDemoSignIn else { return }
        pendingDemoSignIn = false
        do {
            try await signIn(serverTrustPolicy: .system)
        } catch {
            // Remain on credentials; credentialsState.failure is set by signIn.
        }
    }

    private func expectedSteps() -> [AccountCreationStep] {
        var steps: [AccountCreationStep] = []
        if !isEndpointLocked {
            steps.append(.endpoint)
        }
        if shouldPreviewCertificates {
            steps.append(.serverCertificates)
        }
        steps.append(.credentials)
        if credentialsState.signInOutcomeKnown && credentialsState.needsOtp {
            steps.append(.otp)
        }
        steps.append(.done)
        return steps
    }

    private static func shouldPreviewCertificates(for url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }
}

/// Selection payload from a suggestion row tap.
public struct DiscoveryRowSelection: Equatable, Sendable {
    public var candidate: DiscoveryCandidate
    public var seedURL: URL?
    public var isDemo: Bool

    public init(candidate: DiscoveryCandidate, seedURL: URL? = nil, isDemo: Bool = false) {
        self.candidate = candidate
        self.seedURL = seedURL
        self.isDemo = isDemo
    }
}
