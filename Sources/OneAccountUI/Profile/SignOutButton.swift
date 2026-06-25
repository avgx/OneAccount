import SwiftUI
import OneAccount
import ButtonKit

@MainActor
public struct SignOutButton: View {
    @ObservedObject private var accountManager: AccountManager
    @ObservedObject private var currentAccount: CurrentAccount
    private let accountID: AccountID

    public init(
        accountManager: AccountManager,
        currentAccount: CurrentAccount,
        accountID: AccountID
    ) {
        self._accountManager = ObservedObject(wrappedValue: accountManager)
        self._currentAccount = ObservedObject(wrappedValue: currentAccount)
        self.accountID = accountID
    }

    public var body: some View {
        AsyncButton(L10n.string("sign-out")) { @MainActor in
            try await accountManager.delete(accountID)
            let next = accountManager.accounts.isEmpty ? nil : accountManager.accounts.first?.id
            await currentAccount.selectAccount(id: next)
        }
        .foregroundStyle(.red)
    }
}
