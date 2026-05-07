import Foundation
import RequestResponse

extension Backend {
    public func testRequest() -> Request<Void> {
        switch self {
        case .cloud:
            CloudApi.test()
        case .next, .nextLegacy:
            NextApi.test()
        case .intl:
            IntlApi.test()
        }
    }
}
