import SwiftUI
import OneAccount
import SSLPinning

@MainActor
struct ServerCertificatesStep: View {
    let state: CertificatePreviewState
    @Binding var policy: ServerTrustPolicy
    
    var onRetry: () async -> Void
    var onContinue: () async throws -> Void
    
    var body: some View {
        Section {
            if state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let err = state.message {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.footnote)
                Button("Retry") {
                    Task { await onRetry() }
                }
            } else if state.chain.isEmpty {
                Text("No certificate data.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            } else {
                ForEach(state.chain, id: \.sha256) { info in
                    CertificateInfoView(info: info, full: info == state.chain.first)
                }
            }
        } header: {
            headerView
        } footer: {
            Text("Review the TLS chain for this HTTPS endpoint, then continue.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        
        ActionButton(
            title: "Continue",
            isLoading: false,
            isDisabled: state.isLoading
        ) {
            try await onContinue()
        }
        .disabled(state.isLoading)
    }
    
    @ViewBuilder
    var headerView: some View {
        HStack {
            Text("Server certificates")
            
            Spacer()
            
            policyLabel
                .font(.caption2)
        }
    }
    
    @ViewBuilder
    private var policyLabel: some View {
        switch policy {
        case .system:
            Label("System Trust", systemImage: "shield")
        case .trustEveryone:
            Label("Trust All", systemImage: "shield.slash")
        case .pinning(_):
            Label("Pinned Certificates", systemImage: "key.shield")
        case .pinningSpki(_):
            Label("Pinned SPKI", systemImage: "key.shield")
        }
    }
    
    private var policyIcon: String {
        switch policy {
        case .system:
            return "shield"
        case .trustEveryone:
            return "shield.slash"
        case .pinning(_):
            return "key.shield"
        case .pinningSpki(_):
            return "key.shield"
        }
    }
    
//    @ViewBuilder
//    var pinCertificateButton: some View {
//        if case .pinning(_) = policy, let leaf = state.chain.first {
//            Button {
//                pinCertificate(leaf)
//            } label: {
//                Label(
//                    isPinned(leaf) ? "Pinned" : "Pin Certificate",
//                    systemImage: isPinned(leaf)
//                        ? "checkmark.seal.fill"
//                        : "key"
//                )
//            }
//        }
//    }
}


