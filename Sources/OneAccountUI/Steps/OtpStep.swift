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

        if let failure = state.failure {
            Section {
                Text(UserFacingErrorMessage.text(for: failure))
                    .foregroundStyle(.secondary)
            }
        }

        ActionButton(
            title: "verify",
            isDisabled: state.code.count < 4,
            action: onVerify
        )
    }
}
