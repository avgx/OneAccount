import Foundation

extension AccountRecord {
    /// Builds a persisted account from an account-creation draft when URL and backend are resolved.
    public init?(draft: AccountCreationDraft) {
        guard let backend = draft.backend else { return nil }
        let trimmedURL = draft.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, let url = URL(string: trimmedURL) else { return nil }
        let name: String? = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : draft.displayName
        self.init(
            baseURL: url,
            user: draft.user,
            password: draft.password,
            name: name,
            backend: backend,
            session: draft.session
        )
    }
}
