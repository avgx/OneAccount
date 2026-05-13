import SwiftUI
import OneAccount

@MainActor
struct OtpStep: View {

    @Binding var state: OTPState
    var onVerify: () async throws -> Void

    var body: some View {
        OTPField(
            code: $state.code,
            isTotp: $state.isTotp,
            canTotp: state.canTotp
        )

        if let message = state.message, !message.isEmpty {
            Section {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }

        ActionButton(title: "Continue", isLoading: state.isVerifying) {
            try await onVerify()
        }
        .disabled(state.code.count < 4 || state.isVerifying)
    }
}
