import SwiftUI
import OneAccount
import SSLPinning

@MainActor
struct ServerCertificatesStep: View {
    let state: CertificatePreviewState
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(info.subjectSummary ?? info.commonName ?? "Certificate")
                            .font(.headline)
                        Text("S/N: \(info.serialNumber)\nSHA256: \(info.sha256)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
#if !os(tvOS)
                            .textSelection(.enabled)
#else
                            .lineLimit(3)
#endif
                        if let notValidBefore = info.notValidBefore, let notValidAfter = info.notValidAfter {
                            Text("Valid: \(notValidBefore.formatted(date: .abbreviated, time: .omitted)) - \(notValidAfter.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Server certificates")
            //TODO: menu with ServerTrustPolicy
            //icon:
//            shield.slash - trust all
//            shield - trust system
//            key.shield - trust pinned
            //TODO: if pinned - show pin button and already pinned.
            //TODO: проверить на selfsigned cert.
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
}
