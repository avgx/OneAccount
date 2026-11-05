import Foundation
import HTTP

/// Forwards `HTTPClient` failures to a single handler installed later.
///
/// The client is built before the screen that cares about failures exists, so the
/// handler starts empty and is set when that screen is ready.
public actor RequestFailureObserver: RequestObserver {
    private var handler: (@Sendable (URLRequest, Error) async -> Void)?

    public init() {}

    public func setHandler(_ handler: (@Sendable (URLRequest, Error) async -> Void)?) {
        self.handler = handler
    }

    public func didCompleteFailure(_ request: URLRequest, error: Error, duration: TimeInterval) async {
        await handler?(request, error)
    }
}
