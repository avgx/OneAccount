import Foundation

extension URLSessionConfiguration {
    public class var custom120: URLSessionConfiguration {
        let x: URLSessionConfiguration = .ephemeral
        x.timeoutIntervalForRequest = 10
        x.timeoutIntervalForResource = 120
        x.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return x
    }
}
