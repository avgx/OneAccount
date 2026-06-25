import SwiftUI

extension CurrentAccount {
    /// SwiftUI binding for account selection.
    /// `set` schedules `selectAccount(id:)` asynchronously on the main actor.
    @MainActor
    public var selectedAccountIDBinding: Binding<AccountID?> {
        Binding(
            get: { self.selectedId },
            set: { id in
                Task { @MainActor in
                    await self.selectAccount(id: id)
                }
            }
        )
    }
}
