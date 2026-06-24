import SwiftUI
import OneAccount
import SSLPinning

@MainActor
struct ServerCertificatesStep: View {
    let preview: CertificatePreview
    let host: String
    @Binding var policy: ServerTrustPolicy

    var onReload: (ServerTrustPolicy) async -> Void
    var onContinue: () async throws -> Void

    @State private var policyChoice: TrustPolicyChoice
    @State private var expandedCertSHA256s: Set<String> = []

    init(
        preview: CertificatePreview,
        host: String,
        policy: Binding<ServerTrustPolicy>,
        onReload: @escaping (ServerTrustPolicy) async -> Void,
        onContinue: @escaping () async throws -> Void
    ) {
        self.preview = preview
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
            title: "continue",
            isDisabled: isContinueDisabled,
            action: onContinue
        )
        .disabled(isContinueDisabled)
        .onChange(of: policyChoice) { newChoice in
            syncPolicyFromChoice()
            if newChoice == .trustEveryone, preview.chain.isEmpty, !preview.isLoading {
                Task { await onReload(.trustEveryone) }
            }
        }
        .onChange(of: preview.chain) { _ in
            expandedCertSHA256s = []
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
            if preview.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                statusBanner

                if let err = loadErrorMessage {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                    Button(L10n.string("retry")) {
                        Task { await onReload(.system) }
                    }
                }

                if displayedChain.isEmpty, loadErrorMessage == nil {
                    Text("no-certificate-data", bundle: .module)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
        } header: {
            Text("tls-chain", bundle: .module)
        }
    }

    @ViewBuilder
    private var certificateSections: some View {
        if !preview.isLoading {
            ForEach(Array(displayedChain.enumerated()), id: \.element.sha256) { index, info in
                Section {
                    CertificateInfoView(
                        info: info,
                        style: certificateStyle(for: index, sha256: info.sha256),
                        pinHighlight: pinHighlight(for: index)
                    )
                } header: {
                    certificateSectionHeader(for: index, info: info)
                } footer: {
                    if index == 0, info.isSelfSigned == true {
                        Label(L10n.string("self-signed"), systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var policySection: some View {
        Section {
            Picker(L10n.string("trust-policy"), selection: $policyChoice) {
                ForEach(TrustPolicyChoice.allCases) { option in
                    Label {
                        Text(option.titleKey, bundle: .module)
                    } icon: {
                        Image(systemName: option.icon)
                    }
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
        guard preview.chain.isEmpty || policyChoice == .system else { return nil }
        return preview.failure.map { UserFacingErrorMessage.text(for: $0) }
            ?? (preview.chain.isEmpty ? preview.pinningMessage : nil)
    }

    private var isContinueDisabled: Bool {
        if preview.isLoading || preview.chain.isEmpty {
            return true
        }
        if policyChoice == .system, preview.trustStatus?.isTrusted == false {
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
            return Array(preview.chain.prefix(1))
        }
        return preview.chain
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch policyChoice {
        case .system:
            if let trustStatus = preview.trustStatus {
                systemTrustBanner(trustStatus)
            }
        case .pinningCert, .pinningSpki:
            if let pinBannerText {
                pinStatusBanner(text: pinBannerText)
            }
        case .trustEveryone:
            if !preview.chain.isEmpty {
                policyStatusBanner(
                    titleKey: "connection-allowed",
                    systemImage: "checkmark.shield"
                )
            }
        }
    }

    private var pinBannerText: String? {
        guard isPinVerified, let leaf = preview.chain.first else { return nil }
        let name = host.isEmpty ? leaf.commonName : host
        guard !name.isEmpty else { return nil }

        switch policyChoice {
        case .pinningCert:
            return L10n.format("pin-with-hash", name, leaf.sha256)
        case .pinningSpki:
            return L10n.format("pin-with-hash", name, leaf.spki)
        case .system, .trustEveryone:
            return nil
        }
    }

    private var isPinVerified: Bool {
        guard let leaf = preview.chain.first, !host.isEmpty else { return false }
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
            trustStatus.isTrusted ? L10n.string("trusted-by-system") : L10n.string("not-trusted-by-system"),
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
    }

    @ViewBuilder
    private func policyStatusBanner(titleKey: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(titleKey, bundle: .module)
        } icon: {
            Image(systemName: systemImage)
        }
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func roleLabel(for index: Int) -> String {
        if showsLeafDetailsOnly {
            return L10n.string("cert-role-server")
        }
        return role(for: index, count: preview.chain.count)
    }

    private func role(for index: Int, count: Int) -> String {
        if index == 0 {
            return L10n.string("cert-role-server")
        }
        if index == count - 1, count > 1 {
            return L10n.string("cert-role-root")
        }
        return L10n.string("cert-role-intermediate")
    }

    private func isCollapsible(index: Int) -> Bool {
        !showsLeafDetailsOnly && index > 0
    }

    private func isExpanded(sha256: String) -> Bool {
        expandedCertSHA256s.contains(sha256)
    }

    private func toggleExpanded(sha256: String) {
        if expandedCertSHA256s.contains(sha256) {
            expandedCertSHA256s.remove(sha256)
        } else {
            expandedCertSHA256s.insert(sha256)
        }
    }

    private func certificateStyle(for index: Int, sha256: String) -> CertificateInfoView.DisplayStyle {
        if isCollapsible(index: index), !isExpanded(sha256: sha256) {
            return .nameOnly
        }
        let showsFingerprints = showsLeafDetailsOnly || (index == 0 && policyChoice != .system)
        return showsFingerprints ? .fingerprints : .summary
    }

    @ViewBuilder
    private func certificateSectionHeader(for index: Int, info: CertificateInfo) -> some View {
        HStack {
            Text(roleLabel(for: index))
            Spacer()
            if isCollapsible(index: index) {
                Button {
                    toggleExpanded(sha256: info.sha256)
                } label: {
                    Image(systemName: isExpanded(sha256: info.sha256) ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
            }
        }
        .textCase(nil)
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
            if let leaf = preview.chain.first, !host.isEmpty {
                policy = .pinning([Fingerprint(host: host, certificate: leaf)])
            } else {
                policy = .pinning([])
            }
        case .pinningSpki:
            if let leaf = preview.chain.first, !host.isEmpty {
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

    var titleKey: LocalizedStringKey {
        switch self {
        case .system:
            "system-trust"
        case .trustEveryone:
            "trust-all"
        case .pinningCert:
            "pinned-certificates"
        case .pinningSpki:
            "pinned-spki"
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
