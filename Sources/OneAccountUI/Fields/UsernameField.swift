import SwiftUI

@MainActor
public struct UsernameField: View {

    @Binding var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        TextField("user", text: $text)
            .usernameField()
    }
}
