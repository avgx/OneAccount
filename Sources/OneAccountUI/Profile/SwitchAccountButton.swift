import SwiftUI

@MainActor
public struct SwitchAccountButton: View {
    let onSwitchAccount: () -> Void

    public init(onSwitchAccount: @escaping () -> Void) {
        self.onSwitchAccount = onSwitchAccount
    }

    public var body: some View {
        Button(L10n.string("switch-account"), action: onSwitchAccount)
    }
}
