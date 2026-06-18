import Foundation
import SSLPinning

/// Ephemeral ``URLSession`` for endpoint discovery only — accepts any server certificate.
/// User-facing trust is chosen later on the server certificates step.
enum DiscoveryURLSession {
    private static let box = SessionBox()

    static func make() -> URLSession {
        box.session
    }

    private static var fastConfiguration: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return config
    }

    private final class SessionBox: @unchecked Sendable {
        let delegate: TrustEveryoneSessionDelegate
        let session: URLSession

        init() {
            delegate = TrustEveryoneSessionDelegate()
            session = URLSession(
                configuration: DiscoveryURLSession.fastConfiguration,
                delegate: delegate,
                delegateQueue: nil
            )
        }
    }
}

private final class TrustEveryoneSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let evaluator = ServerTrustEvaluator(policy: .trustEveryone)

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let result = evaluator.evaluate(challenge)
        completionHandler(result.disposition, result.credential)
    }
}
