import Foundation

/// Set only while ``AuthBearerTokenProvider/refreshToken()`` runs, which is the 401 retry path.
enum SessionRefreshCause {
    @TaskLocal static var isUnauthorizedRecovery = false
}
