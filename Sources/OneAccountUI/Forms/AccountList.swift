import SwiftUI
import OneAccount

/// Account list with edit mode and selection. Implemented for iOS and tvOS only.
public struct AccountList: View {
    @ObservedObject private var accountManager: AccountManager
    @Binding private var selectedAccountID: AccountID?

    #if !os(macOS)
    @Environment(\.editMode) private var editMode
    #endif
    
    var isEditing: Bool {
        #if os(macOS)
        false
        #else
        editMode?.wrappedValue.isEditing ?? false
        #endif
    }
    
    public init(
        accountManager: AccountManager,
        selectedAccountID: Binding<AccountID?>,
    ) {
        self._accountManager = ObservedObject(wrappedValue: accountManager)
        self._selectedAccountID = selectedAccountID
    }

    public var body: some View {
        List {
            ForEach(accountManager.accounts) { account in
                Button {
                    selectedAccountID = account.id
                } label: {
                    AccountLabel(account)
                    .overlay(alignment: .trailing) {
                        if account.id == selectedAccountID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!isEditing)                
            }
            .onDelete(perform: deleteAccountsAtOffsets)
        }
        .navigationTitle(L10n.string("accounts-title"))
    }
    
    private func dontCommitInvalidateTestOnly(_ id: AccountRecord.ID) {
        Task { @MainActor in
            do {
                guard let record = accountManager.accounts.first(where: { $0.id == id }) else { return }
                if record.session != nil {
                    try await accountManager.store.updateSession(accountID: id, session: nil)
                } else {
                    try await accountManager.store.updatePassword(accountID: id, password: "123456")
                }
                try await accountManager.refresh()
            } catch {
                //TODO: show warning
                return
            }
        }
    }

    private func deleteAccountsAtOffsets(_ offsets: IndexSet) {
        let ids = offsets.map { accountManager.accounts[$0].id }
        Task { @MainActor in
            if let selected = selectedAccountID, ids.contains(selected) {
                selectedAccountID = nil
            }
            for id in ids {
                do {
                    try await accountManager.delete(id)
                } catch {
                    //TODO: show warning
                    return
                }
            }
        }
    }
}
