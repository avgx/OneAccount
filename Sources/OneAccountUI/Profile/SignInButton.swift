import SwiftUI

@MainActor
public struct SignInButton: View {
    let onSignIn: () -> Void

    public init(onSignIn: @escaping () -> Void) {
        self.onSignIn = onSignIn
    }

    public var body: some View {
        Button(L10n.string("sign-in"), action: onSignIn)
            .accessibilityLabel(AccessibilityLabels.signIn)
    }
}
