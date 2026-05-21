import Foundation
import RequestResponse

enum IntlApi {
    static func test() -> Request<Void> {
        let q = [
            ("pageItems", "0"),
            ("_", "\(Int(Date().timeIntervalSince1970 * 1000))"),
        ]
        return Request(path: "secure/configuration", method: .get, query: q)
    }
}
