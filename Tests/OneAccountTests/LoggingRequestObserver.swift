import Foundation
import HTTP
import DebugThings
import Logging

final class LoggingRequestObserver: RequestObserver, @unchecked Sendable {
    let inner: SimpleNetworkLogger
    
    init(logger: Logger = Logger(label: "http")) {
        self.inner = SimpleNetworkLogger(logger: logger, logBody: true) //TODO: Sendable
    }
    
    func willSend(_ request: URLRequest) async {
        inner.logRequest(request)
    }
    func didCompleteSuccess(_ request: URLRequest, response: URLResponse, body: Data, duration: TimeInterval) async {
        inner.logResponse(response as! HTTPURLResponse, body: body, url: request.url!.absoluteString)
    }
    func didCompleteFailure(_ request: URLRequest, error: Error, duration: TimeInterval) async {
        inner.logError(error, url: request.url!.absoluteString)
    }
}
