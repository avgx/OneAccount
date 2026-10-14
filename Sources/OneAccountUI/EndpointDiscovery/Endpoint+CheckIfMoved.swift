import Foundation
import OneAccount
import SSLPinning

extension Endpoint {
    /// Whether a failed connection means this address no longer hosts its server.
    ///
    /// Cloud always returns `false`: it is reached by domain name. `true` only means the app
    /// may offer an optional address change after Retry.
    public func checkIfMoved(error: Error, discovery: DiscoveryClient) async -> Bool {
        guard backend != .cloud, let backend else {
            return false
        }
        if AuthRejection.isRejection(error) || Self.isCertificateFailure(error) || Self.isDeviceOffline(error) {
            return false
        }

        do {
            let found = try await discovery.exploreExact(url, DiscoveryURLSession.make(), discovery.policy)
            return found.backend != backend
        } catch {
            if Self.isDeviceOffline(error) {
                return false
            }
            return true
        }
    }

    private static func isCertificateFailure(_ error: Error) -> Bool {
        error is SSLPinningError || SSLPinningError.systemTrustFailureIfPresent(in: error) != nil
    }

    /// Device or radio problem. An online timeout (`networkUnavailableReason == nil`) is not offline:
    /// the host itself may be gone.
    private static func isDeviceOffline(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        guard let urlError = urlError(from: error) else { return false }
        if urlError.networkUnavailableReason != nil { return true }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .internationalRoamingOff, .cancelled:
            return true
        default:
            return false
        }
    }

    private static func urlError(from error: Error) -> URLError? {
        if let urlError = error as? URLError { return urlError }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return URLError(_nsError: nsError)
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return urlError(from: underlying)
        }
        return nil
    }
}
