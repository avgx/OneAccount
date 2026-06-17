import Combine
import Foundation
import SSLPinning

@MainActor
public final class AccountCreationFlow: ObservableObject {
    @Published public var draft: Draft
    @Published public var step: AccountCreationStep
    @Published public var endpointState = EndpointInputState()
    @Published public var credentialsState = CredentialsState()
    @Published public var otpState = OTPState()
    @Published public var certificatePreview: CertificatePreview = .idle

    public let endpointWizardMode: EndpointWizardMode
    private let useCases: AccountCreationUseCases

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
            initialDraft.url = endpoint.url.absoluteString
            initialDraft.backend = endpoint.backend
            step = Self.shouldPreviewCertificates(for: endpoint.url) ? .serverCertificates : .credentials
        }
        draft = initialDraft

        if step == .serverCertificates {
            Task { await reloadCertificates() }
        }
    }

    public var isEndpointLocked: Bool {
        if case .locked = endpointWizardMode { return true }
        return false
    }

    public var canSave: Bool {
        guard step == .done else { return false }
        return draft.resolvedEndpoint?.backend != nil
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
        guard let endpoint = draft.resolvedEndpoint else { return false }
        return Self.shouldPreviewCertificates(for: endpoint.url)
    }

    public func resetCredentialState() {
        credentialsState.message = nil
        credentialsState.signInOutcomeKnown = false
        credentialsState.needsOtp = false
        credentialsState.otpCanTotp = true
        otpState = OTPState()
        draft.session = nil
    }

    public func selectDiscoveryCandidate(_ candidate: DiscoveryCandidate) async {
        draft.applyDiscoveryCandidate(candidate.endpoint)
        endpointState.message = nil
        await transitionAfterEndpointReady()
    }

    public func resolveEndpoint() async throws {
        guard !isEndpointLocked else { return }
        endpointState.isResolving = true
        endpointState.message = nil
        defer { endpointState.isResolving = false }

        do {
            let resolved = try await useCases.resolveEndpoint(draft.url)
            draft.url = resolved.url.absoluteString
            draft.backend = resolved.backend
            await transitionAfterEndpointReady()
        } catch {
            endpointState.message = Self.endpointMessage(for: error)
            throw error
        }
    }

    public func reloadCertificates(probePolicy: ServerTrustPolicy = .system) async {
        guard let endpoint = draft.resolvedEndpoint else {
            certificatePreview = .failed(.missingEndpoint)
            return
        }
        let preservedTrustStatus = probePolicy == .system ? nil : certificatePreview.trustStatus
        var loaded = await useCases.loadCertificates(
            for: endpoint,
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
    }

    public func signIn() async throws {
        resetCredentialState()
        guard let endpoint = draft.resolvedEndpoint else {
            credentialsState.message = AccountCreationFlowError.missingResolvedEndpoint.localizedDescription
            throw AccountCreationFlowError.missingResolvedEndpoint
        }
        let user = draft.user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !draft.password.isEmpty else {
            credentialsState.message = AccountCreationFlowError.emptyCredentials.localizedDescription
            throw AccountCreationFlowError.emptyCredentials
        }

        credentialsState.isSigningIn = true
        defer { credentialsState.isSigningIn = false }

        do {
            let outcome = try await useCases.validateCredentials(
                AccountCredentialsRequest(endpoint: endpoint, user: user, password: draft.password)
            )
            credentialsState.message = nil
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
            credentialsState.message = error.localizedDescription
            credentialsState.signInOutcomeKnown = false
            throw error
        }
    }

    public func verifyOtp() async throws {
        guard let endpoint = draft.resolvedEndpoint else {
            otpState.message = AccountCreationFlowError.missingResolvedEndpoint.localizedDescription
            throw AccountCreationFlowError.missingResolvedEndpoint
        }
        let code = otpState.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 4 else {
            otpState.message = AccountCreationFlowError.emptyOtp.localizedDescription
            throw AccountCreationFlowError.emptyOtp
        }

        otpState.isVerifying = true
        otpState.message = nil
        defer { otpState.isVerifying = false }

        do {
            let session = try await useCases.verifyOtp(
                OTPVerificationRequest(
                    endpoint: endpoint,
                    user: draft.user.trimmingCharacters(in: .whitespacesAndNewlines),
                    code: code,
                    mode: otpState.isTotp ? .totp : .otp
                )
            )
            draft.session = session
            step = .done
        } catch {
            otpState.message = error.localizedDescription
            throw error
        }
    }

    private func transitionAfterEndpointReady() async {
        resetCredentialState()
        if shouldPreviewCertificates {
            step = .serverCertificates
            await reloadCertificates()
        } else {
            step = .credentials
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

    private static func endpointMessage(for error: Error) -> String {
//        if let failure = error as? WizardEndpointDiscovery.DiscoveryFailure {
//            switch failure {
//            case .emptyInput, .noSeeds:
//                return URLError(.badURL).localizedDescription
//            case .unsupportedBackend:
//                return URLError(.cannotFindHost).localizedDescription
//            case .underlying(let err):
//                return err.localizedDescription
//            }
//        }
        return error.localizedDescription
    }
}
