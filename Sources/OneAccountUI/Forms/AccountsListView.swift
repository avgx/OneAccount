import SwiftUI
import OneAccount

/// Account list with edit mode and selection. Implemented for iOS and tvOS only.
public struct AccountsListView: View {
    @ObservedObject private var accountsViewModel: AccountsViewModel
    @Binding private var selectedAccountID: AccountID?

    @Environment(\.editMode) private var editMode
    
    var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }
    
//    #if os(iOS) || os(tvOS)
//    @State private var editMode: EditMode = .inactive
//    #endif

    public init(
        accountsViewModel: AccountsViewModel,
        selectedAccountID: Binding<AccountID?>,
    ) {
        self._accountsViewModel = ObservedObject(wrappedValue: accountsViewModel)
        self._selectedAccountID = selectedAccountID
    }

    public var body: some View {
        List {
            ForEach(accountsViewModel.accounts) { account in
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
        let ids = offsets.map { accountsViewModel.accounts[$0].id }
        Task { @MainActor in
            if let selected = selectedAccountID, ids.contains(selected) {
                selectedAccountID = nil
            }
            for id in ids {
                do {
                    try await accountsViewModel.delete(id)
                } catch {
                    //TODO: show warning
                    return
                }
            }
        }
    }
}
