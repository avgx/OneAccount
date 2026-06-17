import Foundation
import SSLPinning

public struct CertificatePreviewState: Equatable, Sendable {
    public var isLoading = false
    public var chain: [CertificateInfo] = []
    public var message: String?
    public var trustStatus: SystemTrustStatus?

    public init(
        isLoading: Bool = false,
        chain: [CertificateInfo] = [],
        message: String? = nil,
        trustStatus: SystemTrustStatus? = nil
    ) {
        self.isLoading = isLoading
        self.chain = chain
        self.message = message
        self.trustStatus = trustStatus
    }
}
