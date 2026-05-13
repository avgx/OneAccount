import SwiftUI

@MainActor
public struct PasswordField: View {

    @Binding var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        SecureField("password", text: $text)
            .passwordField()
    }
}
