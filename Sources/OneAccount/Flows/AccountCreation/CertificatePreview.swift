import Foundation
import Resource
import SSLPinning
import TLSDiagnostics

public struct CertificateProbeResult: Equatable, Sendable {
    public let chain: [CertificateInfo]
    public let trustStatus: SystemTrustStatus?
    public let pinningError: SSLPinningError?

    public init(
        chain: [CertificateInfo],
        trustStatus: SystemTrustStatus?,
        pinningError: SSLPinningError?
    ) {
        self.chain = chain
        self.trustStatus = trustStatus
        self.pinningError = pinningError
    }

    init(_ result: TLSProbe.Result) {
        self.init(
            chain: result.chain,
            trustStatus: result.trustStatus,
            pinningError: result.pinningError
        )
    }
}

public enum CertificatePreviewFailure: Error, Equatable, Sendable {
    case missingEndpoint
    case notHTTPS
    case noCertificates(host: String)
    case handshakeFailed(description: String)
    case invalidServerTrust(host: String)
    case systemTrustFailed(description: String)
}

extension CertificatePreviewFailure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            "Select a server before continuing."
        case .notHTTPS:
            "Certificate preview is only available for https URLs."
        case .noCertificates(let host):
            "No server certificate chain was captured for \(host)."
        case .handshakeFailed(let description):
            "TLS handshake failed: \(description)"
        case .invalidServerTrust(let host):
            SSLPinningError.invalidServerTrust(host: host).localizedDescription
        case .systemTrustFailed(let description):
            description
        }
    }
}

public typealias CertificatePreview = Resource<CertificateProbeResult, CertificatePreviewFailure>

extension CertificatePreview {
    public var chain: [CertificateInfo] {
        value?.chain ?? []
    }

    public var trustStatus: SystemTrustStatus? {
        value?.trustStatus
    }

    public var pinningMessage: String? {
        value?.pinningError?.localizedDescription
    }

    public func replacingTrustStatus(_ trustStatus: SystemTrustStatus?) -> CertificatePreview {
        guard let trustStatus, let current = value else { return self }
        let merged = CertificateProbeResult(
            chain: current.chain,
            trustStatus: trustStatus,
            pinningError: current.pinningError
        )
        switch self {
        case .available:
            return .available(merged)
        case .refreshing:
            return .refreshing(merged)
        case .stale(_, let failure):
            return .stale(merged, failure)
        case .idle, .loading, .failed:
            return self
        }
    }
}
