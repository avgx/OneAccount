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
                        Text(info.description)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
#if !os(tvOS)
                            .textSelection(.enabled)
#endif
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Server certificates")
        } footer: {
            Text("Review the TLS chain for this HTTPS endpoint, then continue.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        ActionButton(title: "Continue", isLoading: false) {
            try await onContinue()
        }
        .disabled(state.isLoading)
    }
}
