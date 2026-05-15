import SwiftUI
import OneAccount

/// Account list with edit mode and selection. Implemented for iOS and tvOS only.
public struct AccountsListView: View {
    @ObservedObject private var accountManager: AccountManager
    @Binding private var selectedAccountID: AccountID?

    @Environment(\.editMode) private var editMode
    
    var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }
    
//    #if os(iOS) || os(tvOS)
//    @State private var editMode: EditMode = .inactive
//    #endif

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
                    AccountDetailedLabel(
                        account: account,
                        checkmark: account.id == selectedAccountID
                    )
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!isEditing)
            }
            .onDelete(perform: deleteAccountsAtOffsets)
        }
        .navigationTitle("Accounts")
    }

    private func deleteAccountsAtOffsets(_ offsets: IndexSet) {
        print("deleteAccountsAtOffsets \(offsets)")
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
