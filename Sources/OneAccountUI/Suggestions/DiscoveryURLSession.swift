import Foundation

enum DiscoveryURLSession {
    static func make() -> URLSession {
        URLSession(configuration: fastConfiguration)
    }

    static var fastConfiguration: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return config
    }
}
