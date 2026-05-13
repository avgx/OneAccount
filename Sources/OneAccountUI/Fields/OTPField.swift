import SwiftUI
import OneAccount

@MainActor
public struct OTPField: View {
    @Binding var code: String
    @Binding var isTotp: Bool
    let canTotp: Bool

    public init(code: Binding<String>, isTotp: Binding<Bool>, canTotp: Bool) {
        self._code = code
        self._isTotp = isTotp
        self.canTotp = canTotp
    }

    public var body: some View {
        Section {
            ZStack(alignment: .trailing) {
                TextField("OTP", text: $code)
                    .autocorrectionDisabled()

                pasteButton
            }
        } header: {
            HStack {
                Text("OTP")
                Spacer()
                Toggle(isOn: $isTotp) {
                    Text("TOTP")
                }
                #if !os(tvOS)
                .toggleStyle(.button)
                #endif
            }
        } footer: {
            Text("Enter 6-digit code")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    public var pasteButton: some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            PasteButton(payloadType: String.self) { strings in
                guard let first = strings.first?.filter({ $0.isNumber }) else {
                    return
                }
                Task { @MainActor in
                    code = String(first.prefix(6))
                    hideKeyboard()
                }
            }
            .buttonBorderShape(.circle)
            .labelStyle(.iconOnly)
        }
        #else
        EmptyView()
        #endif
    }
}

public typealias OtpField = OTPField

#Preview {
    List {
        OTPField(code: .constant("123456"), isTotp: .constant(true), canTotp: true)

        OTPField(code: .constant("123456"), isTotp: .constant(false), canTotp: true)

        OTPField(code: .constant("123456"), isTotp: .constant(false), canTotp: false)
    }
}
