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
        .navigationTitle("Accounts")
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
