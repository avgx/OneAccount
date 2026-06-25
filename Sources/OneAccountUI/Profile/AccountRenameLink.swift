import SwiftUI
import OneAccount

@MainActor
public struct AccountRenameLink: View {
    @ObservedObject private var accountManager: AccountManager
    private let accountID: AccountID
    private let onSave: (String) async throws -> Void

    public init(
        accountManager: AccountManager,
        accountID: AccountID,
        onSave: @escaping (String) async throws -> Void
    ) {
        self._accountManager = ObservedObject(wrappedValue: accountManager)
        self.accountID = accountID
        self.onSave = onSave
    }

    private var account: AccountRecord? {
        accountManager.accounts.first { $0.id == accountID }
    }

    public var body: some View {
        if let account {
            NavigationLink {
                AccountEdit(account: account, onSave: onSave)
            } label: {
                HStack {
                    Text(account.name ?? L10n.string("untitled"))
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.caption)
                }
            }
        }
    }
}
