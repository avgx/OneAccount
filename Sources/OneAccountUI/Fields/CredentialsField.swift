import SwiftUI

@MainActor
public struct CredentialsField: View {

    @Binding var user: String
    @Binding var password: String

    let title: LocalizedStringKey

    public init(
        user: Binding<String>,
        password: Binding<String>,
        title: LocalizedStringKey = "Credentials"
    ) {
        self._user = user
        self._password = password
        self.title = title
    }

    public var body: some View {
        Section {
            UsernameField(text: $user)

            PasswordField(text: $password)
        } header: {
            Text(title)
        }
    }
}
