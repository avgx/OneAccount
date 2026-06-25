import SwiftUI
import OneAccount

@MainActor
public struct ManageAccountsLink: View {
    @ObservedObject private var accountManager: AccountManager
    @ObservedObject private var currentAccount: CurrentAccount

    public init(accountManager: AccountManager, currentAccount: CurrentAccount) {
        self._accountManager = ObservedObject(wrappedValue: accountManager)
        self._currentAccount = ObservedObject(wrappedValue: currentAccount)
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(tvOS)
        .primaryAction
        #elseif os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }

    public var body: some View {
        NavigationLink(L10n.string("manage-accounts")) {
            AccountList(
                accountManager: accountManager,
                selectedAccountID: currentAccount.selectedAccountIDBinding
            )
            .toolbar {
                #if os(iOS) || os(visionOS)
                ToolbarItem(placement: toolbarTrailingPlacement) {
                    EditButton()
                }
                #endif
            }
        }
    }
}

@MainActor
public struct ManageAccountsSection: View {
    @ObservedObject private var accountManager: AccountManager
    @ObservedObject private var currentAccount: CurrentAccount

    public init(accountManager: AccountManager, currentAccount: CurrentAccount) {
        self._accountManager = ObservedObject(wrappedValue: accountManager)
        self._currentAccount = ObservedObject(wrappedValue: currentAccount)
    }

    public var body: some View {
        Section {
            ManageAccountsLink(
                accountManager: accountManager,
                currentAccount: currentAccount
            )
        } header: {
            Text(L10n.string("accounts-title"))
        }
    }
}
