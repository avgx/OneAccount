import Foundation

/// Names the refresh contract used when wiring ``Auth`` / HTTP for a concrete backend (Cloud, Next, …).
///
/// Conformance is satisfied by existing ``SessionRefresher`` implementations; this protocol is an app-facing alias.
public protocol BackendAuthenticator: SessionRefresher {}

extension CloudSessionRefresher: BackendAuthenticator {}
extension NextSessionRefresher: BackendAuthenticator {}
