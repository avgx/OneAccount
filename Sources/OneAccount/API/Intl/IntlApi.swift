import Foundation
import RequestResponse

enum IntlApi {
    static func test() -> Request<Void> {
        Request(path: "secure/configuration", method: .get, query: [("pageItems", "0")])
    }
}
