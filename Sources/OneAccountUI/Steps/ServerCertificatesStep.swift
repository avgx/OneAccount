import SwiftUI
import OneAccount
import SSLPinning

@MainActor
struct ServerCertificatesStep: View {
    let state: CertificatePreviewState
    let host: String
    @Binding var policy: ServerTrustPolicy

    var onReload: (ServerTrustPolicy) async -> Void
    var onContinue: () async throws -> Void

    @State private var policyChoice: TrustPolicyChoice

    init(
        state: CertificatePreviewState,
        host: String,
        policy: Binding<ServerTrustPolicy>,
        onReload: @escaping (ServerTrustPolicy) async -> Void,
        onContinue: @escaping () async throws -> Void
    ) {
        self.state = state
        self.host = host
        self._policy = policy
        self.onReload = onReload
        self.onContinue = onContinue
        _policyChoice = State(initialValue: TrustPolicyChoice(policy: policy.wrappedValue))
    }

    var body: some View {
        statusSection
        certificateSections
        policySection
        continueButton
    }

    private var continueButton: some View {
        ActionButton(
            title: "Continue",
            isLoading: false,
            isDisabled: isContinueDisabled
        ) {
            try await onContinue()
        }
        .disabled(isContinueDisabled)
        .onChange(of: policyChoice) { newChoice in
            syncPolicyFromChoice()
            if newChoice == .trustEveryone, state.chain.isEmpty, !state.isLoading {
                Task { await onReload(.trustEveryone) }
            }
        }
        .onChange(of: state.chain) { _ in
            switch policyChoice {
            case .pinningCert, .pinningSpki:
                syncPolicyFromChoice()
            case .system, .trustEveryone:
                break
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Section {
            if state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                statusBanner

                if let err = loadErrorMessage {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                    Button("Retry") {
                        Task { await onReload(.system) }
                    }
                }

                if displayedChain.isEmpty, loadErrorMessage == nil {
                    Text("No certificate data.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
        } header: {
            Text("TLS chain")
        }
    }

    @ViewBuilder
    private var certificateSections: some View {
        if !state.isLoading {
            ForEach(Array(displayedChain.enumerated()), id: \.element.sha256) { index, info in
                Section {
                    CertificateInfoView(
                        info: info,
                        full: showsLeafDetailsOnly ? true : index == 0 && policyChoice != .system,
                        pinHighlight: pinHighlight(for: index)
                    )
                } header: {
                    Text(roleLabel(for: index))
                } footer: {
                    if index == 0, info.isSelfSigned == true {
                        Label("Self-signed", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var policySection: some View {
        Section {
            Picker("Trust policy", selection: $policyChoice) {
                ForEach(TrustPolicyChoice.allCases) { option in
                    Label(option.title, systemImage: option.icon)
                        .labelStyle(.titleOnly)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
        } footer: {
            Text(policy.localizedDescription())
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// Probe errors from the last network load (system policy), or when the chain is still empty.
    private var loadErrorMessage: String? {
        guard state.chain.isEmpty || policyChoice == .system else { return nil }
        return state.message
    }

    private var isContinueDisabled: Bool {
        if state.isLoading || state.chain.isEmpty {
            return true
        }
        if policyChoice == .system, state.trustStatus?.isTrusted == false {
            return true
        }
        return false
    }

    private var showsLeafDetailsOnly: Bool {
        switch policyChoice {
        case .pinningCert, .pinningSpki:
            return true
        case .system, .trustEveryone:
            return false
        }
    }

    private var displayedChain: [CertificateInfo] {
        if showsLeafDetailsOnly {
            return Array(state.chain.prefix(1))
        }
        return state.chain
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch policyChoice {
        case .system:
            if let trustStatus = state.trustStatus {
                systemTrustBanner(trustStatus)
            }
        case .pinningCert, .pinningSpki:
            if let pinBannerText {
                pinStatusBanner(text: pinBannerText)
            }
        case .trustEveryone:
            if !state.chain.isEmpty {
                policyStatusBanner(
                    title: "Connection allowed",
                    systemImage: "checkmark.shield"
                )
            }
        }
    }

    private var pinBannerText: String? {
        guard isPinVerified, let leaf = state.chain.first else { return nil }
        let name = host.isEmpty ? leaf.commonName : host
        guard !name.isEmpty else { return nil }

        switch policyChoice {
        case .pinningCert:
            let prefix = String(leaf.sha256.prefix(6))
            return "Pin \(name) with \(prefix)…"
        case .pinningSpki:
            let prefix = String(leaf.spki.prefix(6))
            return "Pin \(name) with \(prefix)…"
        case .system, .trustEveryone:
            return nil
        }
    }

    private var isPinVerified: Bool {
        guard let leaf = state.chain.first, !host.isEmpty else { return false }
        switch policyChoice {
        case .pinningCert:
            guard case .pinning(let pins) = policy else { return false }
            return pins.contains { pin in
                pin.host.caseInsensitiveCompare(host) == .orderedSame
                    && pin.sha256 == leaf.sha256
                    && !pin.isSPKIOnly
            }
        case .pinningSpki:
            guard case .pinningSpki(let pins) = policy else { return false }
            return pins.contains { pin in
                pin.host.caseInsensitiveCompare(host) == .orderedSame
                    && pin.sha256 == leaf.spki
                    && pin.isSPKIOnly
            }
        case .system, .trustEveryone:
            return false
        }
    }

    @ViewBuilder
    private func systemTrustBanner(_ trustStatus: SystemTrustStatus) -> some View {
        Label(
            trustStatus.isTrusted ? "Trusted by system" : "Not trusted by system",
            systemImage: trustStatus.isTrusted ? "checkmark.shield" : "xmark.shield"
        )
        .font(.footnote)
        .foregroundColor(trustStatus.isTrusted ? Color.secondary : Color.red)
    }

    @ViewBuilder
    private func pinStatusBanner(text: String) -> some View {
        Label {
            Text(text)
                .lineLimit(1)
        } icon: {
            Image(systemName: "checkmark.seal")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func policyStatusBanner(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
    }

    private func roleLabel(for index: Int) -> String {
        if showsLeafDetailsOnly {
            return "Server"
        }
        return role(for: index, count: state.chain.count)
    }

    private func role(for index: Int, count: Int) -> String {
        if index == 0 {
            return "Server"
        }
        if index == count - 1, count > 1 {
            return "Root"
        }
        return "Intermediate"
    }

    private func pinHighlight(for index: Int) -> CertificateInfoView.PinHighlight {
        guard index == 0 else { return .none }
        switch policyChoice {
        case .pinningCert:
            return .certificate
        case .pinningSpki:
            return .spki
        case .system, .trustEveryone:
            return .none
        }
    }

    private func syncPolicyFromChoice() {
        switch policyChoice {
        case .system:
            policy = .system
        case .trustEveryone:
            policy = .trustEveryone
        case .pinningCert:
            if let leaf = state.chain.first, !host.isEmpty {
                policy = .pinning([Fingerprint(host: host, certificate: leaf)])
            } else {
                policy = .pinning([])
            }
        case .pinningSpki:
            if let leaf = state.chain.first, !host.isEmpty {
                policy = .pinningSpki([Fingerprint(host: host, spkiFrom: leaf)])
            } else {
                policy = .pinningSpki([])
            }
        }
    }
}

private enum TrustPolicyChoice: String, CaseIterable, Identifiable {
    case system
    case pinningCert
    case pinningSpki
    case trustEveryone

    var id: String { rawValue }

    init(policy: ServerTrustPolicy) {
        switch policy {
        case .system:
            self = .system
        case .trustEveryone:
            self = .trustEveryone
        case .pinning:
            self = .pinningCert
        case .pinningSpki:
            self = .pinningSpki
        }
    }

    var title: String {
        switch self {
        case .system:
            "System Trust"
        case .trustEveryone:
            "Trust All"
        case .pinningCert:
            "Pinned Certificates"
        case .pinningSpki:
            "Pinned SPKI"
        }
    }

    var icon: String {
        switch self {
        case .system:
            "shield"
        case .trustEveryone:
            "shield.slash"
        case .pinningCert, .pinningSpki:
            "key.shield"
        }
    }
}
