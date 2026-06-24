import SwiftUI

@MainActor
public struct UsernameField: View {

    @Binding var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        TextField(L10n.string("field-user"), text: $text)
            .usernameField()
    }
}
