import SwiftUI

@MainActor
public struct AddAccountButton: View {
    let onAddAccount: () -> Void

    public init(onAddAccount: @escaping () -> Void) {
        self.onAddAccount = onAddAccount
    }

    public var body: some View {
        Button(L10n.string("add-account"), action: onAddAccount)
    }
}
