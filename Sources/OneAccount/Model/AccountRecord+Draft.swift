import Foundation

extension AccountRecord {
    /// Builds a persisted account from an account-creation draft when the endpoint is resolved.
    public init?(draft: Draft) {
        guard let endpoint = draft.resolvedEndpoint else { return nil }
        let name: String? = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : draft.displayName
        self.init(
            baseURL: endpoint.url,
            user: draft.user,
            password: draft.password,
            name: name,
            backend: endpoint.backend,
            session: draft.session,
            serverTrustPolicy: draft.serverTrustPolicy
        )
    }
}
