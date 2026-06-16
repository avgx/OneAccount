import Foundation
import SSLPinning

public struct CertificatePreviewState: Equatable, Sendable {
    public var isLoading = false
    public var chain: [CertificateInfo] = []
    public var message: String?

    public init(
        isLoading: Bool = false,
        chain: [CertificateInfo] = [],
        message: String? = nil
    ) {
        self.isLoading = isLoading
        self.chain = chain
        self.message = message
    }
}
