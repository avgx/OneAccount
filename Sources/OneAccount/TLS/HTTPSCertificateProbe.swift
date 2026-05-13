import Foundation
import SSLPinning

//TODO: use samples / code from tests from SSLPinning. Simplify this.

public enum HTTPSCertificateProbeError: LocalizedError, Equatable {
    case notHTTPS
    case noCertificates(host: String)

    public var errorDescription: String? {
        switch self {
        case .notHTTPS:
            "Certificate preview is only available for https URLs."
        case .noCertificates(let host):
            "No server certificate chain was captured for \(host)."
        }
    }
}

private final class ProbeURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    let evaluator: ServerTrustEvaluator

    init(policy: ServerTrustPolicy) {
        self.evaluator = ServerTrustEvaluator(policy: policy)
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let result = evaluator.evaluate(challenge)
        completionHandler(result.disposition, result.credential)
    }
}

/// Second TLS handshake used by the account wizard to display the server certificate chain with the same ``ServerTrustPolicy`` as the HTTP client.
public enum HTTPSCertificateProbe: Sendable {
    /// Performs a lightweight request and returns certificate snapshots from the TLS handshake.
    public static func fetchCertificateChain(url: URL, serverTrustPolicy: ServerTrustPolicy) async throws -> [CertificateInfo] {
        guard url.scheme?.lowercased() == "https" else {
            throw HTTPSCertificateProbeError.notHTTPS
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CertificateInfo], any Error>) in
            let delegate = ProbeURLSessionDelegate(policy: serverTrustPolicy)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 25
            configuration.timeoutIntervalForResource = 30
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            let task = session.dataTask(with: request) { _, _, error in
                session.finishTasksAndInvalidate()
                if let error {
                    if let ssl = SSLPinningError.systemTrustFailureIfPresent(in: error) {
                        continuation.resume(throwing: ssl)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                let hostKey = (url.host ?? "").lowercased()
                let chain: [CertificateInfo] = {
                    if let exact = delegate.evaluator.certificateChainsByHost[url.host ?? ""] {
                        return exact
                    }
                    return delegate.evaluator.certificateChainsByHost.first(where: { $0.key.lowercased() == hostKey })?.value ?? []
                }()
                if chain.isEmpty {
                    continuation.resume(throwing: HTTPSCertificateProbeError.noCertificates(host: url.host ?? "(no host)"))
                } else {
                    continuation.resume(returning: chain)
                }
            }
            task.resume()
        }
    }
}
